package com.adultcode.miniwebcam.camera

/** Everything the user (or a remote client) can change. Mirrors lib/shared/models.dart. */
data class CameraSettings(
    var camera: String = "back",
    var width: Int = 1280,
    var height: Int = 720,
    var fps: Int = 30,
    var codec: String = CODEC_H264,
    var bitrate: Int = 6_000_000,
    var jpegQuality: Int = 75,
    var zoom: Float = 1f,
    var torch: Boolean = false,
    var focusMode: String = FOCUS_AUTO,
    var focusDistance: Float = 0f,
    var exposure: Int = 0,
) {
    enum class Change { NONE, LIVE, BITRATE, RESTART }

    fun toMap(): Map<String, Any> = mapOf(
        "camera" to camera,
        "resolution" to "${width}x$height",
        "fps" to fps,
        "codec" to codec,
        "bitrate" to bitrate,
        "jpegQuality" to jpegQuality,
        "zoom" to zoom.toDouble(),
        "torch" to torch,
        "focusMode" to focusMode,
        "focusDistance" to focusDistance.toDouble(),
        "exposure" to exposure,
    )

    /** Applies a (partial) update and reports the most disruptive kind of change. */
    fun apply(map: Map<*, *>): Change {
        var change = Change.NONE
        fun bump(c: Change) {
            if (c.ordinal > change.ordinal) change = c
        }

        (map["camera"] as? String)?.takeIf { it != camera && it in listOf("back", "front") }?.let {
            camera = it
            torch = false
            zoom = 1f
            bump(Change.RESTART)
        }
        (map["resolution"] as? String)?.let { parseSize(it) }?.let { (w, h) ->
            if (w != width || h != height) {
                width = w
                height = h
                bump(Change.RESTART)
            }
        }
        (map["fps"] as? Number)?.toInt()?.takeIf { it != fps && it in 5..120 }?.let {
            fps = it
            bump(Change.RESTART)
        }
        (map["codec"] as? String)?.takeIf { it != codec && it in listOf(CODEC_H264, CODEC_MJPEG) }?.let {
            codec = it
            bump(Change.RESTART)
        }
        (map["bitrate"] as? Number)?.toInt()?.coerceIn(250_000, 50_000_000)?.takeIf { it != bitrate }?.let {
            bitrate = it
            bump(Change.BITRATE)
        }
        (map["jpegQuality"] as? Number)?.toInt()?.coerceIn(10, 100)?.let { jpegQuality = it }
        (map["zoom"] as? Number)?.toFloat()?.let {
            zoom = it
            bump(Change.LIVE)
        }
        (map["torch"] as? Boolean)?.let {
            torch = it
            bump(Change.LIVE)
        }
        (map["focusMode"] as? String)?.takeIf { it in listOf(FOCUS_AUTO, FOCUS_MANUAL) }?.let {
            focusMode = it
            bump(Change.LIVE)
        }
        (map["focusDistance"] as? Number)?.toFloat()?.coerceIn(0f, 1f)?.let {
            focusDistance = it
            bump(Change.LIVE)
        }
        (map["exposure"] as? Number)?.toInt()?.let {
            exposure = it
            bump(Change.LIVE)
        }
        return change
    }

    companion object {
        const val CODEC_H264 = "h264"
        const val CODEC_MJPEG = "mjpeg"
        const val FOCUS_AUTO = "auto"
        const val FOCUS_MANUAL = "manual"

        fun parseSize(s: String): Pair<Int, Int>? {
            val parts = s.lowercase().split('x')
            if (parts.size != 2) return null
            val w = parts[0].trim().toIntOrNull() ?: return null
            val h = parts[1].trim().toIntOrNull() ?: return null
            return if (w > 0 && h > 0) w to h else null
        }
    }
}
