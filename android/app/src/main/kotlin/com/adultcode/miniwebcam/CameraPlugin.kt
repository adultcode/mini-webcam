package com.adultcode.miniwebcam

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.adultcode.miniwebcam.camera.CameraEngine
import com.adultcode.miniwebcam.stream.StreamHub
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Bridges Dart (UI + control HTTP server) to the native capture/encode/stream pipeline.
 * Only small control messages cross this channel; video frames stay native.
 */
class CameraPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private val main = Handler(Looper.getMainLooper())
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null

    // --- camera permission (no third-party plugin needed) -----------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    /** Replies "granted", "denied" or "permanentlyDenied". */
    private fun requestCameraPermission(result: MethodChannel.Result) {
        val activity = activityBinding?.activity
        if (context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
            return
        }
        if (activity == null || pendingPermission != null) {
            result.success("denied")
            return
        }
        pendingPermission = result
        activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val result = pendingPermission ?: return true
        pendingPermission = null
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        val activity = activityBinding?.activity
        result.success(
            when {
                granted -> "granted"
                // No rationale after a denial means "don't ask again" was chosen.
                activity != null && !activity.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA) ->
                    "permanentlyDenied"
                else -> "denied"
            }
        )
        return true
    }

    private val hub = StreamHub()
    private var engine: CameraEngine? = null
    private var lastStatsAt = SystemClock.elapsedRealtime()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "miniwebcam/camera")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        engine?.release()
        engine = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "create") {
            val e = engine ?: CameraEngine(
                context, hub, binding.textureRegistry.createSurfaceProducer()
            ).also { engine = it }
            result.success(
                mapOf(
                    "textureId" to e.textureId,
                    "handlesCropAndRotation" to e.handlesCropAndRotation,
                )
            )
            return
        }
        if (call.method == "deviceInfo") {
            result.success(mapOf("name" to "${Build.MANUFACTURER} ${Build.MODEL}", "sdk" to Build.VERSION.SDK_INT))
            return
        }
        if (call.method == "requestPermission") {
            requestCameraPermission(result)
            return
        }
        if (call.method == "openAppSettings") {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            result.success(null)
            return
        }

        val e = engine
        if (e == null) {
            result.error("no_engine", "Call create() first", null)
            return
        }
        // Run on the camera thread, answer on the platform thread.
        e.handler.post {
            val reply: Result<Any?> = runCatching {
                when (call.method) {
                    "open" -> { e.open(); null }
                    "close" -> { e.close(); null }
                    "setStreaming" -> { e.setStreaming(call.argument<Boolean>("enabled") == true); null }
                    "update" -> {
                        e.update(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                        mapOf("settings" to e.settings.toMap(), "features" to e.features())
                    }
                    "focusAt" -> {
                        e.focusAt(
                            (call.argument<Double>("x") ?: 0.5).toFloat(),
                            (call.argument<Double>("y") ?: 0.5).toFloat(),
                        )
                        null
                    }
                    "getSettings" -> e.settings.toMap()
                    "getFeatures" -> e.features()
                    "getStats" -> stats(e)
                    else -> NOT_IMPLEMENTED
                }
            }
            main.post {
                reply.fold(
                    onSuccess = { if (it === NOT_IMPLEMENTED) result.notImplemented() else result.success(it) },
                    onFailure = { result.error("native_error", it.message, null) },
                )
            }
        }
    }

    private fun stats(e: CameraEngine): Map<String, Any?> {
        val now = SystemClock.elapsedRealtime()
        val seconds = ((now - lastStatsAt).coerceAtLeast(1)) / 1000.0
        lastStatsAt = now
        val (bytes, frames, dropped) = hub.drainCounters()
        return mapOf(
            "state" to e.state,
            "error" to e.lastError,
            "streaming" to e.streaming,
            "fcamClients" to hub.fcamClientCount,
            "mjpegClients" to hub.mjpegClientCount,
            "fps" to frames / seconds,
            "kbps" to bytes * 8 / 1000.0 / seconds,
            "dropped" to dropped,
            "width" to e.actualSize.width,
            "height" to e.actualSize.height,
            "codec" to e.settings.codec,
        )
    }

    private companion object {
        const val PERMISSION_REQUEST = 4711
        val NOT_IMPLEMENTED = Any()
    }
}
