package com.adultcode.miniwebcam.stream

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.SystemClock
import android.util.Log
import android.view.Surface

private const val TAG = "MiniWebcamEncoder"

/**
 * Hardware H.264 encoder fed directly by the camera through an input [Surface].
 * Frames never touch the CPU or the Dart VM on their way to the network.
 */
class H264Encoder(
    private val width: Int,
    private val height: Int,
    private val fps: Int,
    bitrate: Int,
    private val listener: Listener,
) {
    interface Listener {
        fun onCodecConfig(config: ByteArray)
        fun onFrame(data: ByteArray, ptsUs: Long, keyframe: Boolean)
    }

    private val codec: MediaCodec = MediaCodec.createEncoderByType(MIME)
    lateinit var inputSurface: Surface
        private set

    @Volatile private var running = false
    private var lastKeyframeRequest = 0L
    private var currentBitrate = bitrate

    fun start(handler: Handler) {
        val caps = codec.codecInfo.getCapabilitiesForType(MIME)
        val format = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, currentBitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            // Short GOP so a receiver that joins or drops packets recovers quickly.
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            // Keep emitting frames when the scene is static so receivers never time out.
            setLong(MediaFormat.KEY_REPEAT_PREVIOUS_FRAME_AFTER, 1_000_000L / fps * 3)
            // Realtime priority.
            setInteger(MediaFormat.KEY_PRIORITY, 0)
            if (caps.encoderCapabilities.isBitrateModeSupported(
                    MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR
                )
            ) {
                setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // SPS/PPS in front of every IDR, B-frames off (they add a frame of latency).
                setInteger(MediaFormat.KEY_PREPEND_HEADER_TO_SYNC_FRAMES, 1)
                setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
            }
        }

        codec.setCallback(callback, handler)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = codec.createInputSurface()
        codec.start()
        running = true
        Log.i(TAG, "Encoder ${codec.name} started ${width}x$height@$fps ${currentBitrate / 1000} kbps")
    }

    fun stop() {
        if (!running) return
        running = false
        runCatching { codec.stop() }
        runCatching { codec.release() }
        runCatching { inputSurface.release() }
    }

    fun requestKeyframe() {
        if (!running) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastKeyframeRequest < 250) return
        lastKeyframeRequest = now
        runCatching {
            codec.setParameters(Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0) })
        }
    }

    /** Changes the bitrate on the fly, without restarting the encoder. */
    fun setBitrate(bitrate: Int) {
        if (!running || bitrate == currentBitrate) return
        currentBitrate = bitrate
        runCatching {
            codec.setParameters(Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_VIDEO_BITRATE, bitrate) })
        }
    }

    private val callback = object : MediaCodec.Callback() {
        override fun onInputBufferAvailable(codec: MediaCodec, index: Int) = Unit

        override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
            if (!running) return
            try {
                val buffer = codec.getOutputBuffer(index)
                if (buffer != null && info.size > 0) {
                    buffer.position(info.offset)
                    buffer.limit(info.offset + info.size)
                    val bytes = ByteArray(info.size)
                    buffer.get(bytes)
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        listener.onCodecConfig(bytes)
                    } else {
                        val key = info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
                        listener.onFrame(bytes, info.presentationTimeUs, key)
                    }
                }
                codec.releaseOutputBuffer(index, false)
            } catch (e: IllegalStateException) {
                // Codec was stopped while a callback was in flight.
            }
        }

        override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
            Log.e(TAG, "Encoder error", e)
        }

        override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
            // Some encoders only report SPS/PPS here instead of a CODEC_CONFIG buffer.
            val sps = format.getByteBuffer("csd-0") ?: return
            val pps = format.getByteBuffer("csd-1")
            val config = ByteArray(sps.remaining() + (pps?.remaining() ?: 0))
            sps.get(config, 0, sps.remaining())
            pps?.get(config, config.size - pps.remaining(), pps.remaining())
            listener.onCodecConfig(config)
        }
    }

    companion object {
        const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC

        private val supportCache = java.util.concurrent.ConcurrentHashMap<String, Boolean>()

        /** True if some hardware/software AVC encoder can handle this size and rate. */
        fun supports(width: Int, height: Int, fps: Int): Boolean = supportCache.getOrPut("${width}x$height@$fps") {
            val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            list.codecInfos.any { info ->
                info.isEncoder && info.supportedTypes.any { it.equals(MIME, ignoreCase = true) } &&
                    runCatching {
                        info.getCapabilitiesForType(MIME).videoCapabilities
                            .areSizeAndRateSupported(width, height, fps.toDouble())
                    }.getOrDefault(false)
            }
        }
    }
}
