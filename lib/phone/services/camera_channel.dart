import 'package:flutter/services.dart';

import '../../core/models/camera_models.dart';

/// Thin wrapper over the native Android pipeline (CameraPlugin.kt).
/// Only control messages go through here; frames stay native.
class CameraChannel {
  static const _channel = MethodChannel('miniwebcam/camera');

  Future<({int textureId, bool handlesRotation})> create() async {
    final r = await _channel.invokeMapMethod<String, dynamic>('create');
    return (
      textureId: (r!['textureId'] as num).toInt(),
      handlesRotation: r['handlesCropAndRotation'] as bool? ?? false,
    );
  }

  Future<String> deviceName() async {
    final r = await _channel.invokeMapMethod<String, dynamic>('deviceInfo');
    return r?['name'] as String? ?? 'Android phone';
  }

  /// Returns "granted", "denied" or "permanentlyDenied".
  Future<String> requestPermission() async =>
      await _channel.invokeMethod<String>('requestPermission') ?? 'denied';

  Future<void> openAppSettings() => _channel.invokeMethod('openAppSettings');

  Future<void> open() => _channel.invokeMethod('open');
  Future<void> close() => _channel.invokeMethod('close');

  Future<void> setStreaming(bool enabled) =>
      _channel.invokeMethod('setStreaming', {'enabled': enabled});

  /// Applies a partial settings update and returns the effective state.
  Future<({CameraSettings settings, CameraFeatures features})> update(
      Map<String, dynamic> changes) async {
    final r = await _channel.invokeMapMethod<String, dynamic>('update', changes);
    return (
      settings: CameraSettings.fromMap(r!['settings'] as Map),
      features: CameraFeatures.fromMap(r['features'] as Map),
    );
  }

  Future<void> focusAt(double x, double y) =>
      _channel.invokeMethod('focusAt', {'x': x, 'y': y});

  Future<Map<String, dynamic>> stats() async =>
      await _channel.invokeMapMethod<String, dynamic>('getStats') ?? {};
}
