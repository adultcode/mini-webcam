package com.adultcode.miniwebcam.stream

import android.util.Log
import java.io.BufferedOutputStream
import java.io.IOException
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

private const val TAG = "MiniWebcamHub"

/**
 * Fans encoded frames out to every connected receiver.
 *
 * Two listeners run while the hub is started:
 *  - FCAM binary stream on [FcamProtocol.STREAM_PORT] (used by the Windows client)
 *  - MJPEG over HTTP on [FcamProtocol.MJPEG_PORT] (browsers, OBS, VLC) when in MJPEG mode
 *
 * Each client owns a small bounded queue and a writer thread, so one slow receiver can
 * never stall the encoder or the other receivers. When a queue overflows the client is
 * flushed and, for H.264, waits for the next keyframe (which is requested immediately)
 * instead of building up latency.
 */
class StreamHub {
    @Volatile private var hello: Packet? = null
    @Volatile private var codecConfig: Packet? = null
    @Volatile var latestJpeg: ByteArray? = null
        private set
    @Volatile var mjpegEnabled = false

    /** Invoked (from any thread) when a client needs a fresh keyframe. */
    var onKeyframeRequest: (() -> Unit)? = null

    private val clients = CopyOnWriteArrayList<Client>()
    private var fcamServer: ServerSocket? = null
    private var mjpegServer: ServerSocket? = null
    @Volatile private var running = false

    private val bytesSent = AtomicLong()
    private val framesOut = AtomicLong()
    private val framesDropped = AtomicLong()

    val isRunning: Boolean get() = running
    val fcamClientCount: Int get() = clients.count { it is FcamClient }
    val mjpegClientCount: Int get() = clients.count { it is MjpegClient }
    val hasConsumers: Boolean get() = clients.isNotEmpty()

    fun start() {
        if (running) return
        running = true
        fcamServer = openServer(FcamProtocol.STREAM_PORT)
        mjpegServer = openServer(FcamProtocol.MJPEG_PORT)
        fcamServer?.let { s -> thread("fcam-accept") { acceptLoop(s, ::onFcamSocket) } }
        mjpegServer?.let { s -> thread("mjpeg-accept") { acceptLoop(s, ::onHttpSocket) } }
    }

    fun stop() {
        running = false
        runCatching { fcamServer?.close() }
        runCatching { mjpegServer?.close() }
        fcamServer = null
        mjpegServer = null
        clients.forEach { it.close() }
        clients.clear()
    }

    /** Called when the stream format changes. Pushes the new HELLO to every client. */
    fun setHello(json: String) {
        val p = FcamProtocol.packet(FcamProtocol.TYPE_HELLO, json.toByteArray(), 0, true)
        hello = p
        codecConfig = null
        latestJpeg = null
        clients.forEach { if (it is FcamClient) it.enqueueControl(p) }
    }

    fun setCodecConfig(config: ByteArray) {
        val p = FcamProtocol.packet(FcamProtocol.TYPE_CODEC_CONFIG, config, 0, true)
        codecConfig = p
        clients.forEach { if (it is FcamClient) it.enqueueControl(p) }
    }

    fun publishH264(data: ByteArray, ptsUs: Long, keyframe: Boolean) {
        if (clients.isEmpty()) return
        val p = FcamProtocol.packet(FcamProtocol.TYPE_H264, data, ptsUs, keyframe)
        framesOut.incrementAndGet()
        clients.forEach { it.offer(p) }
    }

    fun publishJpeg(data: ByteArray, ptsUs: Long) {
        latestJpeg = data
        if (clients.isEmpty()) return
        val p = FcamProtocol.packet(FcamProtocol.TYPE_JPEG, data, ptsUs, true)
        framesOut.incrementAndGet()
        clients.forEach { it.offer(p) }
    }

    /** Returns and resets the counters accumulated since the previous call. */
    fun drainCounters(): Triple<Long, Long, Long> =
        Triple(bytesSent.getAndSet(0), framesOut.getAndSet(0), framesDropped.getAndSet(0))

    // --- sockets --------------------------------------------------------------------

    private fun openServer(port: Int): ServerSocket? = try {
        ServerSocket().apply {
            reuseAddress = true
            bind(InetSocketAddress(port))
        }
    } catch (e: IOException) {
        Log.e(TAG, "Cannot listen on port $port", e)
        null
    }

    private fun acceptLoop(server: ServerSocket, handler: (Socket) -> Unit) {
        while (running) {
            val socket = try {
                server.accept()
            } catch (_: IOException) {
                break
            }
            try {
                socket.tcpNoDelay = true
                socket.keepAlive = true
                socket.sendBufferSize = 512 * 1024
                handler(socket)
            } catch (e: Exception) {
                Log.w(TAG, "Client setup failed", e)
                runCatching { socket.close() }
            }
        }
    }

    private fun onFcamSocket(socket: Socket) {
        val client = FcamClient(socket)
        hello?.let { client.enqueueControl(it) }
        codecConfig?.let { client.enqueueControl(it) }
        register(client)
        onKeyframeRequest?.invoke()
    }

    private fun onHttpSocket(socket: Socket) {
        // Parse the request off the accept thread; browsers may be slow to send it.
        thread("mjpeg-request") {
            try {
                socket.soTimeout = 5000
                val path = readRequestPath(socket)
                socket.soTimeout = 0
                val out = BufferedOutputStream(socket.getOutputStream(), 64 * 1024)
                when {
                    path.startsWith("/snapshot") -> {
                        val jpeg = latestJpeg
                        if (jpeg == null) {
                            writeText(out, 503, "No frame available yet")
                        } else {
                            out.write(
                                ("HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\n" +
                                    "Content-Length: ${jpeg.size}\r\nConnection: close\r\n\r\n").toByteArray()
                            )
                            out.write(jpeg)
                            out.flush()
                        }
                        socket.close()
                    }
                    !mjpegEnabled -> {
                        writeText(out, 503, "Phone is streaming H.264. Switch the codec to MJPEG to use this endpoint.")
                        socket.close()
                    }
                    else -> {
                        out.write(
                            ("HTTP/1.1 200 OK\r\n" +
                                "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n" +
                                "Cache-Control: no-cache, no-store\r\nPragma: no-cache\r\n" +
                                "Access-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n").toByteArray()
                        )
                        out.flush()
                        register(MjpegClient(socket, out))
                    }
                }
            } catch (_: IOException) {
                runCatching { socket.close() }
            }
        }
    }

    private fun readRequestPath(socket: Socket): String {
        val input = socket.getInputStream()
        val buf = StringBuilder()
        var matched = 0
        val terminator = "\r\n\r\n"
        while (buf.length < 8192) {
            val c = input.read()
            if (c < 0) break
            buf.append(c.toChar())
            matched = if (c.toChar() == terminator[matched]) matched + 1 else if (c == '\r'.code) 1 else 0
            if (matched == terminator.length) break
        }
        // "GET /video HTTP/1.1"
        return buf.lineSequence().firstOrNull()?.split(' ')?.getOrNull(1) ?: "/"
    }

    private fun writeText(out: OutputStream, code: Int, text: String) {
        val body = text.toByteArray()
        val reason = if (code == 200) "OK" else "Service Unavailable"
        out.write(
            ("HTTP/1.1 $code $reason\r\nContent-Type: text/plain; charset=utf-8\r\n" +
                "Content-Length: ${body.size}\r\nConnection: close\r\n\r\n").toByteArray()
        )
        out.write(body)
        out.flush()
    }

    private fun register(client: Client) {
        if (!running) {
            client.close()
            return
        }
        clients.add(client)
        client.start()
        Log.i(TAG, "Client connected: ${client.name} (total ${clients.size})")
    }

    private fun unregister(client: Client) {
        if (clients.remove(client)) {
            Log.i(TAG, "Client disconnected: ${client.name} (total ${clients.size})")
        }
    }

    private fun thread(name: String, body: () -> Unit) =
        Thread(body, name).apply { isDaemon = true; start() }

    // --- clients --------------------------------------------------------------------

    private abstract inner class Client(protected val socket: Socket) {
        val name: String = socket.remoteSocketAddress.toString()
        protected val queue = ArrayBlockingQueue<Packet>(QUEUE_CAPACITY)
        @Volatile protected var closed = false
        private var writer: Thread? = null

        abstract fun accepts(p: Packet): Boolean
        abstract fun write(p: Packet)

        open fun offer(p: Packet) {
            if (closed || !accepts(p)) return
            if (!queue.offer(p)) {
                // Receiver can't keep up: drop the backlog rather than add latency.
                framesDropped.addAndGet(queue.size.toLong() + 1)
                queue.clear()
                onOverflow(p)
            }
        }

        protected open fun onOverflow(p: Packet) {
            queue.offer(p)
        }

        fun start() {
            writer = thread("writer-$name") { writeLoop() }
        }

        private fun writeLoop() {
            try {
                while (!closed) {
                    val p = queue.poll(500, TimeUnit.MILLISECONDS) ?: continue
                    write(p)
                    bytesSent.addAndGet(p.data.size.toLong())
                }
            } catch (_: IOException) {
            } catch (_: InterruptedException) {
            } finally {
                close()
            }
        }

        fun close() {
            if (closed) return
            closed = true
            runCatching { socket.close() }
            unregister(this)
        }
    }

    private inner class FcamClient(socket: Socket) : Client(socket) {
        private val out = BufferedOutputStream(socket.getOutputStream(), 256 * 1024)
        @Volatile private var waitingForKeyframe = true

        override fun accepts(p: Packet): Boolean {
            if (p.type == FcamProtocol.TYPE_H264) {
                if (waitingForKeyframe && !p.keyframe) return false
                if (p.keyframe) waitingForKeyframe = false
            }
            return true
        }

        override fun onOverflow(p: Packet) {
            if (p.type == FcamProtocol.TYPE_H264 && !p.keyframe) {
                // Decoder needs a keyframe to resync after the dropped frames.
                hello?.let { queue.offer(it) }
                codecConfig?.let { queue.offer(it) }
                waitingForKeyframe = true
                onKeyframeRequest?.invoke()
            } else {
                queue.offer(p)
            }
        }

        /** HELLO / codec config bypass keyframe gating and are never dropped. */
        fun enqueueControl(p: Packet) {
            if (p.type == FcamProtocol.TYPE_HELLO) waitingForKeyframe = true
            if (!queue.offer(p)) {
                queue.clear()
                queue.offer(p)
            }
        }

        override fun write(p: Packet) {
            out.write(p.data)
            out.flush()
        }
    }

    private inner class MjpegClient(socket: Socket, private val out: OutputStream) : Client(socket) {
        override fun accepts(p: Packet) = p.type == FcamProtocol.TYPE_JPEG

        override fun write(p: Packet) {
            out.write(
                ("--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${p.payloadSize}\r\n\r\n").toByteArray()
            )
            out.write(p.data, FcamProtocol.HEADER_SIZE, p.payloadSize)
            out.write(CRLF)
            out.flush()
        }
    }

    private companion object {
        const val QUEUE_CAPACITY = 6
        val CRLF = "\r\n".toByteArray()
    }
}
