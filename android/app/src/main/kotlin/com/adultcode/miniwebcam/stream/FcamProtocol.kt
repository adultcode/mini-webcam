package com.adultcode.miniwebcam.stream

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * FCAM wire protocol (phone -> desktop, TCP port [FcamProtocol.STREAM_PORT]).
 *
 * Every packet starts with a fixed 16-byte big-endian header:
 *
 *   offset size  field
 *   0      2     magic  'F' 'C'
 *   2      1     type   (see TYPE_*)
 *   3      1     flags  bit0 = keyframe
 *   4      8     pts    presentation time in microseconds
 *   12     4     length payload size in bytes
 *
 * The first packet a client receives is always TYPE_HELLO (UTF-8 JSON describing the
 * stream). It is re-sent whenever the stream format changes, so receivers must reset
 * their decoder on every HELLO.
 *
 * Compared to the original MJPEG-over-HTTP + RTSP pair this is a single, length-prefixed
 * binary stream: no boundary scanning, no RTSP/RTP handshake, H.264 straight from the
 * hardware encoder and per-client back-pressure handling.
 */
object FcamProtocol {
    const val STREAM_PORT = 8555
    const val MJPEG_PORT = 8081
    const val CONTROL_PORT = 8080
    const val VERSION = 1

    const val HEADER_SIZE = 16

    const val TYPE_HELLO: Byte = 0x01
    const val TYPE_H264: Byte = 0x02
    const val TYPE_JPEG: Byte = 0x03
    const val TYPE_CODEC_CONFIG: Byte = 0x04

    const val FLAG_KEYFRAME = 0x01

    fun packet(type: Byte, payload: ByteArray, ptsUs: Long, keyframe: Boolean): Packet {
        val data = ByteArray(HEADER_SIZE + payload.size)
        val header = ByteBuffer.wrap(data, 0, HEADER_SIZE).order(ByteOrder.BIG_ENDIAN)
        header.put('F'.code.toByte())
        header.put('C'.code.toByte())
        header.put(type)
        header.put(if (keyframe) FLAG_KEYFRAME.toByte() else 0)
        header.putLong(ptsUs)
        header.putInt(payload.size)
        System.arraycopy(payload, 0, data, HEADER_SIZE, payload.size)
        return Packet(type, data, keyframe)
    }
}

/** An immutable, fully serialized packet shared by every connected client. */
class Packet(val type: Byte, val data: ByteArray, val keyframe: Boolean) {
    val payloadSize: Int get() = data.size - FcamProtocol.HEADER_SIZE
}
