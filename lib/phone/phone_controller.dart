import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../shared/models.dart';
import '../shared/protocol.dart';
import 'camera_channel.dart';
import 'control_server.dart';
import 'discovery_beacon.dart';

/// Owns the phone-side state: native camera, control server and discovery.
class PhoneController extends ChangeNotifier {
  final _camera = CameraChannel();
  late final ControlServer _server = ControlServer(
    info: _info,
    status: () async => _stats,
    state: _state,
    update: (changes) async {
      await applyChanges(changes);
      return _state();
    },
    focus: (x, y) => _camera.focusAt(x, y),
  );
  late final DiscoveryBeacon _beacon = DiscoveryBeacon(() => {
        'name': deviceName,
        'control': FcamPorts.controlPort,
        'stream': FcamPorts.streamPort,
        'streaming': streaming,
      });

  static const _prefsKey = 'phone.settings';

  int? textureId;
  bool handlesRotation = false;
  bool permissionDenied = false;
  String? error;
  String deviceName = 'Android phone';
  CameraSettings settings = const CameraSettings();
  CameraFeatures features = const CameraFeatures();
  bool streaming = false;
  Map<String, dynamic> _stats = const {};
  List<String> addresses = const [];
  Timer? _statsTimer;

  int get fcamClients => (_stats['fcamClients'] as num?)?.toInt() ?? 0;
  int get mjpegClients => (_stats['mjpegClients'] as num?)?.toInt() ?? 0;
  double get fps => (_stats['fps'] as num?)?.toDouble() ?? 0;
  double get kbps => (_stats['kbps'] as num?)?.toDouble() ?? 0;
  String get cameraState => _stats['state'] as String? ?? 'idle';

  Future<void> init() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      permissionDenied = true;
      notifyListeners();
      return;
    }
    permissionDenied = false;

    final created = await _camera.create();
    textureId = created.textureId;
    handlesRotation = created.handlesRotation;
    deviceName = await _camera.deviceName();

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final initial = saved == null
        ? const <String, dynamic>{}
        : (jsonDecode(saved) as Map).cast<String, dynamic>();
    await _apply(initial);
    await _camera.open();

    await WakelockPlus.enable();
    await _refreshAddresses();
    try {
      await _server.start();
    } on SocketException catch (e) {
      error = 'Control server failed: ${e.message}';
    }
    await _beacon.start();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    notifyListeners();
  }

  Future<void> retryPermission() async {
    if (await Permission.camera.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await init();
    }
  }

  Future<void> setStreaming(bool enabled) async {
    streaming = enabled;
    await _camera.setStreaming(enabled);
    await _refreshAddresses();
    // The native side may have adjusted resolution/fps to what the camera supports.
    await _apply(const {});
  }

  /// Applies changes coming from the UI or a remote desktop client.
  /// Accepts the extra key `streaming` so the desktop can start the stream.
  Future<void> applyChanges(Map<String, dynamic> changes) async {
    final copy = Map<String, dynamic>.from(changes);
    final wantStreaming = copy.remove('streaming');
    if (wantStreaming is bool && wantStreaming != streaming) {
      await setStreaming(wantStreaming);
    }
    if (copy.isNotEmpty) await _apply(copy);
  }

  Future<void> focusAt(double x, double y) => _camera.focusAt(x, y);

  Future<void> onResume() async {
    if (textureId == null) {
      if (permissionDenied) await init();
      return;
    }
    if (cameraState == 'error') await _camera.open();
    await _refreshAddresses();
  }

  Future<void> _apply(Map<String, dynamic> changes) async {
    try {
      final r = await _camera.update(changes);
      settings = r.settings;
      features = r.features;
      error = null;
      final prefs = await SharedPreferences.getInstance();
      final persisted = settings.toMap()
        ..remove('torch')
        ..remove('zoom');
      await prefs.setString(_prefsKey, jsonEncode(persisted));
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> _poll() async {
    try {
      _stats = await _camera.stats();
      final nativeError = _stats['error'] as String?;
      if (nativeError != null) error = nativeError;
      if (_stats['state'] == 'running' && error != null && nativeError == null) {
        error = null;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      addresses = [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (!a.isLoopback) a.address,
      ];
    } catch (_) {
      addresses = const [];
    }
  }

  Map<String, dynamic> _info() => {
        'app': FcamDiscovery.app,
        'version': FcamDiscovery.version,
        'device': deviceName,
        'streamPort': FcamPorts.streamPort,
        'mjpegPort': FcamPorts.mjpegPort,
        'streaming': streaming,
      };

  Map<String, dynamic> _state() => {
        'settings': settings.toMap(),
        'features': features.toMap(),
        'streaming': streaming,
      };

  @override
  void dispose() {
    _statsTimer?.cancel();
    _beacon.stop();
    _server.stop();
    _camera.close();
    WakelockPlus.disable();
    super.dispose();
  }
}
