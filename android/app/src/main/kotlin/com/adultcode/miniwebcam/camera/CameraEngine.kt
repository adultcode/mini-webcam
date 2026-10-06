package com.adultcode.miniwebcam.camera

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.MeteringRectangle
import android.media.MediaCodec
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Range
import android.util.Size
import android.view.Surface
import com.adultcode.miniwebcam.stream.H264Encoder
import com.adultcode.miniwebcam.stream.JpegEncoder
import com.adultcode.miniwebcam.stream.StreamHub
import io.flutter.view.TextureRegistry
import org.json.JSONObject
import kotlin.math.abs

private const val TAG = "MiniWebcamCamera"

/**
 * Camera2 pipeline. One capture session feeds up to two surfaces:
 *   - the Flutter preview texture
 *   - the stream sink: H.264 encoder input surface, or a YUV ImageReader for MJPEG
 *
 * All camera state is confined to [handler]'s thread.
 */
@SuppressLint("MissingPermission") // Checked on the Dart side before open() is called.
class CameraEngine(
    context: Context,
    private val hub: StreamHub,
    private val producer: TextureRegistry.SurfaceProducer,
) {
    private val manager = context.getSystemService(CameraManager::class.java)
    private val cameraThread = HandlerThread("miniwebcam-camera").apply { start() }
    private val encoderThread = HandlerThread("miniwebcam-encoder").apply { start() }
    val handler = Handler(cameraThread.looper)
    private val encoderHandler = Handler(encoderThread.looper)

    val textureId: Long get() = producer.id()
    val handlesCropAndRotation: Boolean get() = producer.handlesCropAndRotation()

    val settings = CameraSettings()
    var streaming = false
        private set
    var state = "idle"
        private set
    var lastError: String? = null
        private set
    var actualSize = Size(settings.width, settings.height)
        private set

    private var active = false
    private var generation = 0
    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var chars: CameraCharacteristics? = null
    @Volatile private var encoder: H264Encoder? = null
    private var jpeg: JpegEncoder? = null
    private var previewSurface: Surface? = null
    private var focusRegion: MeteringRectangle? = null
    private val resetFocus = Runnable {
        focusRegion = null
        updateRepeating()
    }

    init {
        hub.onKeyframeRequest = { encoder?.requestKeyframe() }
        producer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                handler.post { if (active) restart() }
            }

            override fun onSurfaceCleanup() {
                // Runs on the platform thread and the surface dies when we return,
                // so stop using it synchronously.
                val done = java.util.concurrent.CountDownLatch(1)
                handler.post {
                    closeCamera()
                    done.countDown()
                }
                done.await(1, java.util.concurrent.TimeUnit.SECONDS)
            }
        })
    }

    // --- public API (call on handler thread) ------------------------------------------

    fun open() {
        active = true
        restart()
    }

    fun close() {
        active = false
        closeCamera()
        state = "idle"
    }

    fun setStreaming(enabled: Boolean) {
        if (enabled == streaming) return
        streaming = enabled
        if (enabled) hub.start() else hub.stop()
        if (active) restart()
    }

    fun update(map: Map<*, *>) {
        when (settings.apply(map)) {
            CameraSettings.Change.RESTART -> if (active) restart()
            CameraSettings.Change.BITRATE -> encoder?.setBitrate(settings.bitrate)
            CameraSettings.Change.LIVE -> updateRepeating()
            CameraSettings.Change.NONE -> Unit
        }
        jpeg?.quality = settings.jpegQuality
    }

    /** Tap-to-focus. [x], [y] are normalized (0..1) in sensor orientation. */
    fun focusAt(x: Float, y: Float) {
        val c = chars ?: return
        val active = c.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE) ?: return
        val area = if (usesZoomRatio(c)) Rect(0, 0, active.width(), active.height()) else cropRegion(c)
        val cx = area.left + (x.coerceIn(0f, 1f) * area.width()).toInt()
        val cy = area.top + (y.coerceIn(0f, 1f) * area.height()).toInt()
        val half = (area.width() * 0.08f).toInt().coerceAtLeast(16)
        val rect = Rect(
            (cx - half).coerceAtLeast(0), (cy - half).coerceAtLeast(0),
            (cx + half).coerceAtMost(active.width() - 1), (cy + half).coerceAtMost(active.height() - 1),
        )
        focusRegion = MeteringRectangle(rect, MeteringRectangle.METERING_WEIGHT_MAX - 1)
        settings.focusMode = CameraSettings.FOCUS_AUTO

        val s = session ?: return
        val trigger = buildRequest() ?: return
        trigger.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_START)
        runCatching {
            s.capture(trigger.build(), null, handler)
            updateRepeating()
        }
        handler.removeCallbacks(resetFocus)
        handler.postDelayed(resetFocus, 5000)
    }

    fun features(): Map<String, Any> {
        val id = cameraId(settings.camera)
        val c = chars ?: id?.let { manager.getCameraCharacteristics(it) }
        val cameras = listOfNotNull(
            cameraId("back")?.let { "back" },
            cameraId("front")?.let { "front" },
        )
        if (c == null) return mapOf("cameras" to cameras)

        val zoom = zoomRange(c)
        val ev = c.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE) ?: Range(0, 0)
        val evStep = c.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)?.toDouble() ?: 0.0
        return mapOf(
            "cameras" to cameras,
            "resolutions" to supportedSizes(c).map { "${it.width}x${it.height}" },
            "fps" to supportedFps(c),
            "zoomMin" to zoom.lower.toDouble(),
            "zoomMax" to zoom.upper.toDouble(),
            "hasFlash" to (c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true),
            "manualFocus" to supportsManualFocus(c),
            "exposureMin" to ev.lower,
            "exposureMax" to ev.upper,
            "exposureStep" to evStep,
            "sensorOrientation" to (c.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90),
            "frontFacing" to (c.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT),
        )
    }

    fun release() {
        handler.post {
            close()
            hub.stop()
            cameraThread.quitSafely()
            encoderThread.quitSafely()
        }
    }

    // --- session lifecycle ------------------------------------------------------------

    private fun restart() {
        closeCamera()
        val gen = ++generation
        state = "starting"
        lastError = null

        val id = cameraId(settings.camera)
        if (id == null) {
            fail("No ${settings.camera} camera on this device")
            return
        }
        val c = manager.getCameraCharacteristics(id)
        chars = c

        val size = pickSize(c, settings.width, settings.height)
        settings.width = size.width
        settings.height = size.height
        actualSize = size
        settings.fps = pickFpsRange(c, settings.fps).upper.coerceAtMost(settings.fps)
        clampLiveSettings(c)

        producer.setSize(size.width, size.height)

        if (streaming) {
            try {
                createStreamSink(size)
            } catch (e: Exception) {
                fail("Encoder setup failed: ${e.message}")
                return
            }
        }

        try {
            manager.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    if (gen != generation) {
                        camera.close()
                        return
                    }
                    device = camera
                    createSession(camera, gen)
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    if (gen == generation) {
                        device = null
                        fail("Camera disconnected (in use by another app?)")
                    }
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    if (gen == generation) {
                        device = null
                        fail("Camera error $error")
                    }
                }
            }, handler)
        } catch (e: Exception) {
            fail("Cannot open camera: ${e.message}")
        }
    }

    private fun createStreamSink(size: Size) {
        val helloJson = JSONObject()
            .put("version", com.adultcode.miniwebcam.stream.FcamProtocol.VERSION)
            .put("codec", settings.codec)
            .put("width", size.width)
            .put("height", size.height)
            .put("fps", settings.fps)
            .put("camera", settings.camera)
            .put("device", "${Build.MANUFACTURER} ${Build.MODEL}")
            .toString()
        hub.mjpegEnabled = settings.codec == CameraSettings.CODEC_MJPEG
        hub.setHello(helloJson)

        if (settings.codec == CameraSettings.CODEC_MJPEG) {
            jpeg = JpegEncoder(size.width, size.height, settings.jpegQuality, hub).also { it.start(encoderHandler) }
        } else {
            encoder = H264Encoder(size.width, size.height, settings.fps, settings.bitrate,
                object : H264Encoder.Listener {
                    override fun onCodecConfig(config: ByteArray) = hub.setCodecConfig(config)
                    override fun onFrame(data: ByteArray, ptsUs: Long, keyframe: Boolean) =
                        hub.publishH264(data, ptsUs, keyframe)
                }).also { it.start(encoderHandler) }
        }
    }

    @Suppress("DEPRECATION") // SessionConfiguration needs API 28; this path works on 26+.
    private fun createSession(camera: CameraDevice, gen: Int) {
        val preview = producer.surface
        previewSurface = preview
        val surfaces = listOfNotNull(preview, encoder?.inputSurface, jpeg?.surface)
        try {
            camera.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(s: CameraCaptureSession) {
                    if (gen != generation) {
                        s.close()
                        return
                    }
                    session = s
                    state = "running"
                    updateRepeating()
                }

                override fun onConfigureFailed(s: CameraCaptureSession) {
                    if (gen == generation) fail("Camera rejected ${settings.width}x${settings.height}; try a lower resolution")
                }
            }, handler)
        } catch (e: Exception) {
            fail("Session failed: ${e.message}")
        }
    }

    private fun closeCamera() {
        generation++
        handler.removeCallbacks(resetFocus)
        focusRegion = null
        runCatching { session?.close() }
        session = null
        runCatching { device?.close() }
        device = null
        encoder?.stop()
        encoder = null
        jpeg?.stop()
        jpeg = null
        previewSurface = null
    }

    private fun fail(message: String) {
        Log.e(TAG, message)
        state = "error"
        lastError = message
    }

    // --- capture request --------------------------------------------------------------

    private fun buildRequest(): CaptureRequest.Builder? {
        val d = device ?: return null
        val c = chars ?: return null
        val b = d.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
        previewSurface?.let { b.addTarget(it) }
        encoder?.let { b.addTarget(it.inputSurface) }
        jpeg?.let { b.addTarget(it.surface) }

        b.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
        b.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
        b.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, pickFpsRange(c, settings.fps))
        b.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, settings.exposure)
        b.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_OFF)

        val afModes = c.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES) ?: IntArray(0)
        val region = focusRegion
        when {
            settings.focusMode == CameraSettings.FOCUS_MANUAL && supportsManualFocus(c) -> {
                val minFocus = c.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0f
                b.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_OFF)
                b.set(CaptureRequest.LENS_FOCUS_DISTANCE, settings.focusDistance * minFocus)
            }
            region != null && CameraMetadata.CONTROL_AF_MODE_AUTO in afModes -> {
                b.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_AUTO)
                if ((c.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF) ?: 0) > 0) {
                    b.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(region))
                }
                if ((c.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE) ?: 0) > 0) {
                    b.set(CaptureRequest.CONTROL_AE_REGIONS, arrayOf(region))
                }
            }
            CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO in afModes ->
                b.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
        }

        if (c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true) {
            b.set(
                CaptureRequest.FLASH_MODE,
                if (settings.torch) CameraMetadata.FLASH_MODE_TORCH else CameraMetadata.FLASH_MODE_OFF,
            )
        }

        if (usesZoomRatio(c)) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                b.set(CaptureRequest.CONTROL_ZOOM_RATIO, settings.zoom)
            }
        } else {
            b.set(CaptureRequest.SCALER_CROP_REGION, cropRegion(c))
        }
        return b
    }

    private fun updateRepeating() {
        val s = session ?: return
        val c = chars ?: return
        clampLiveSettings(c)
        val b = buildRequest() ?: return
        try {
            s.setRepeatingRequest(b.build(), null, handler)
        } catch (e: Exception) {
            Log.w(TAG, "setRepeatingRequest failed", e)
        }
    }

    // --- capability helpers -----------------------------------------------------------

    private fun cameraId(facing: String): String? {
        val want = if (facing == "front") CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK
        return manager.cameraIdList.firstOrNull {
            manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == want
        }
    }

    private fun supportedSizes(c: CameraCharacteristics): List<Size> {
        val map = c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) ?: return emptyList()
        val preview = map.getOutputSizes(SurfaceTexture::class.java)?.toSet() ?: emptySet()
        val sink = if (settings.codec == CameraSettings.CODEC_MJPEG) {
            map.getOutputSizes(ImageFormat.YUV_420_888)?.toSet() ?: emptySet()
        } else {
            map.getOutputSizes(MediaCodec::class.java)?.toSet() ?: emptySet()
        }
        return STANDARD_SIZES.filter { it in preview && it in sink }
            .filter { settings.codec == CameraSettings.CODEC_MJPEG || H264Encoder.supports(it.width, it.height, 30) }
    }

    private fun pickSize(c: CameraCharacteristics, w: Int, h: Int): Size {
        val sizes = supportedSizes(c)
        if (sizes.isEmpty()) return Size(w, h)
        return sizes.firstOrNull { it.width == w && it.height == h }
            ?: sizes.minBy { abs(it.width * it.height - w * h) }
    }

    private fun supportedFps(c: CameraCharacteristics): List<Int> {
        val ranges = c.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES) ?: return listOf(30)
        return ranges.map { it.upper }.filter { it in listOf(15, 24, 30, 60) }.distinct().sorted()
            .ifEmpty { listOf(30) }
    }

    /** Prefers a fixed range [fps, fps] for steady frame pacing, else the widest one ending at fps. */
    private fun pickFpsRange(c: CameraCharacteristics, fps: Int): Range<Int> {
        val ranges = c.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
            ?: return Range(fps, fps)
        return ranges.filter { it.upper == fps }.maxByOrNull { it.lower }
            ?: ranges.minBy { abs(it.upper - fps) * 100 - it.lower }
    }

    private fun usesZoomRatio(c: CameraCharacteristics): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            c.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE) != null

    private fun zoomRange(c: CameraCharacteristics): Range<Float> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            c.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)?.let { return it }
        }
        val max = c.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM) ?: 1f
        return Range(1f, max.coerceAtLeast(1f))
    }

    private fun cropRegion(c: CameraCharacteristics): Rect {
        val active = c.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE) ?: return Rect()
        val z = settings.zoom.coerceIn(1f, zoomRange(c).upper)
        val w = (active.width() / z).toInt()
        val h = (active.height() / z).toInt()
        val left = (active.width() - w) / 2
        val top = (active.height() - h) / 2
        return Rect(left, top, left + w, top + h)
    }

    private fun supportsManualFocus(c: CameraCharacteristics): Boolean {
        val minFocus = c.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0f
        val caps = c.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES) ?: IntArray(0)
        return minFocus > 0f && CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR in caps
    }

    private fun clampLiveSettings(c: CameraCharacteristics) {
        val zoom = zoomRange(c)
        settings.zoom = settings.zoom.coerceIn(zoom.lower, zoom.upper)
        val ev = c.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
        settings.exposure = if (ev == null) 0 else settings.exposure.coerceIn(ev.lower, ev.upper)
        if (c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) != true) settings.torch = false
        if (!supportsManualFocus(c)) settings.focusMode = CameraSettings.FOCUS_AUTO
    }

    private companion object {
        val STANDARD_SIZES = listOf(
            Size(640, 360), Size(640, 480), Size(960, 540), Size(1280, 720),
            Size(1920, 1080), Size(2560, 1440), Size(3840, 2160),
        )
    }
}
