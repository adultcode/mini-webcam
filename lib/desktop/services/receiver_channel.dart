import 'package:flutter/services.dart';

/// Bridge to the native Windows receiver (windows/runner/fcam).
/// Decoding, preview upload and virtual-camera output all happen natively.
class ReceiverChannel {
  static const _channel = MethodChannel('miniwebcam/receiver');

  Future<int> textureId() async =>
      (await _channel.invokeMethod<num>('textureId'))!.toInt();

  Future<void> connect(String host, int port) =>
      _channel.invokeMethod('connect', {'host': host, 'port': port});

  Future<void> disconnect() => _channel.invokeMethod('disconnect');

  Future<ReceiverStatus> status() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('status');
    return ReceiverStatus(m ?? const {});
  }

  Future<void> setTransform({required int rotation, required bool mirror}) =>
      _channel.invokeMethod('setTransform', {'rotation': rotation, 'mirror': mirror});

  Future<void> setPreview(bool enabled) =>
      _channel.invokeMethod('setPreview', {'enabled': enabled});

  Future<void> setVirtualCamera(bool enabled) =>
      _channel.invokeMethod('setVirtualCamera', {'enabled': enabled});

  /// Saves the current preview frame as a PNG at [path].
  Future<void> snapshot(String path) => _channel.invokeMethod('snapshot', {'path': path});

  /// DirectShow video devices visible to other apps (Zoom, Teams, OBS...).
  Future<List<String>> listCameras() async =>
      (await _channel.invokeListMethod<String>('listCameras')) ?? const [];
}

class ReceiverStatus {
  const ReceiverStatus(this._m);
  final Map<String, dynamic> _m;

  String get state => _m['state'] as String? ?? 'idle';
  String get message => _m['message'] as String? ?? '';
  String get codec => _m['codec'] as String? ?? '';
  String get device => _m['device'] as String? ?? '';
  int get width => (_m['width'] as num?)?.toInt() ?? 0;
  int get height => (_m['height'] as num?)?.toInt() ?? 0;
  double get fps => (_m['fps'] as num?)?.toDouble() ?? 0;
  double get kbps => (_m['kbps'] as num?)?.toDouble() ?? 0;
  double get decodeMs => (_m['decodeMs'] as num?)?.toDouble() ?? 0;
  int get decodeErrors => (_m['decodeErrors'] as num?)?.toInt() ?? 0;
  bool get vcamEnabled => _m['vcamEnabled'] as bool? ?? false;
  bool get vcamActive => _m['vcamActive'] as bool? ?? false;
  bool get vcamAppConnected => _m['vcamAppConnected'] as bool? ?? false;
  String get vcamError => _m['vcamError'] as String? ?? '';

  bool get isStreaming => state == 'streaming';
  bool get isIdle => state == 'idle';
}
