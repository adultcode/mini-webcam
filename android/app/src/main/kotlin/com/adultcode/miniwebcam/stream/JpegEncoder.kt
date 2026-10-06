package com.adultcode.miniwebcam.stream

import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import android.media.ImageReader
import android.os.Handler
import java.io.ByteArrayOutputStream

/**
 * MJPEG path: camera -> YUV_420_888 [ImageReader] -> NV21 -> JPEG.
 * Only does work while somebody is actually watching (see [StreamHub.hasConsumers]).
 */
class JpegEncoder(
    width: Int,
    height: Int,
    @Volatile var quality: Int,
    private val hub: StreamHub,
) {
    private val reader = ImageReader.newInstance(width, height, ImageFormat.YUV_420_888, 3)
    val surface get() = reader.surface

    private val nv21 = ByteArray(width * height * 3 / 2)
    private val jpegOut = ByteArrayOutputStream(width * height / 4)
    private val rect = Rect(0, 0, width, height)
    private var yPlane = ByteArray(0)
    private var uPlane = ByteArray(0)
    private var vPlane = ByteArray(0)

    fun start(handler: Handler) {
        reader.setOnImageAvailableListener({ r ->
            val image = r.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                if (hub.hasConsumers || hub.latestJpeg == null) encode(image)
            } finally {
                image.close()
            }
        }, handler)
    }

    fun stop() {
        reader.setOnImageAvailableListener(null, null)
        reader.close()
    }

    private fun encode(image: Image) {
        toNv21(image)
        jpegOut.reset()
        YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
            .compressToJpeg(rect, quality.coerceIn(10, 100), jpegOut)
        hub.publishJpeg(jpegOut.toByteArray(), image.timestamp / 1000)
    }

    /** Converts any YUV_420_888 layout (planar or semi-planar, padded rows) to NV21. */
    private fun toNv21(image: Image) {
        val w = image.width
        val h = image.height
        val planes = image.planes

        yPlane = copyPlane(planes[0].buffer, yPlane)
        val yRow = planes[0].rowStride
        var pos = 0
        if (yRow == w) {
            System.arraycopy(yPlane, 0, nv21, 0, w * h)
            pos = w * h
        } else {
            for (row in 0 until h) {
                System.arraycopy(yPlane, row * yRow, nv21, pos, w)
                pos += w
            }
        }

        uPlane = copyPlane(planes[1].buffer, uPlane)
        vPlane = copyPlane(planes[2].buffer, vPlane)
        val uRow = planes[1].rowStride
        val vRow = planes[2].rowStride
        val uPix = planes[1].pixelStride
        val vPix = planes[2].pixelStride
        for (row in 0 until h / 2) {
            var u = row * uRow
            var v = row * vRow
            for (col in 0 until w / 2) {
                nv21[pos++] = vPlane[v]
                nv21[pos++] = uPlane[u]
                u += uPix
                v += vPix
            }
        }
    }

    private fun copyPlane(src: java.nio.ByteBuffer, reuse: ByteArray): ByteArray {
        src.rewind()
        val size = src.remaining()
        val dst = if (reuse.size >= size) reuse else ByteArray(size)
        src.get(dst, 0, size)
        return dst
    }
}
