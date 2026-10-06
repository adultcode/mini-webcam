import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/protocol.dart';
import '../services/adb.dart';
import '../services/discovery_listener.dart';
import '../services/phone_api.dart';
import '../services/receiver_channel.dart';
import '../services/virtual_cam_installer.dart';
import 'output_aspect.dart';

export 'output_aspect.dart';

enum ConnectionMode { wifi, usb }

/// Desktop-side state: receiver, connection, adb, discovery and output options.
/// Exposed to the UI with `ChangeNotifierProvider<DesktopProvider>`.
class DesktopProvider extends ChangeNotifier {
  final receiver = ReceiverChannel();
  final adb = Adb();
  final discovery = DiscoveryListener();

  late SharedPreferences _prefs;
  StreamSubscription<List<DiscoveredPhone>>? _discoverySub;
  Timer? _statusTimer;
  Timer? _phoneTimer;
  int _polls = 0;

  int? textureId;
  ReceiverStatus status = const ReceiverStatus({});
  ConnectionMode mode = ConnectionMode.wifi;
  String lastHost = '';
  String? target; // what we're connected (or connecting) to, for display
  ConnectionMode? connectedVia;
  bool active = false;
  String? error;

  PhoneApi? _api;
  PhoneState? phone;

  List<DiscoveredPhone> discovered = const [];
  List<AdbDevice> adbDevices = const [];
  String? adbError;
  bool adbBusy = false;

  int rotation = 0;
  bool mirror = false;
  OutputAspect aspect = OutputAspect.original;
  bool aspectFill = false;
  bool preview = true;
  bool vcamEnabled = true;
  List<String> systemCameras = const [];
  bool driverBusy = false;

  bool get driverInstalled =>
      systemCameras.contains(VirtualCamInstaller.deviceName);

  /// Loads saved settings, starts discovery, then applies startup arguments.
  Future<void> start(List<String> args) async {
    await init();
    await autoConnect(args);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    lastHost = _prefs.getString('desktop.host') ?? '';
    mode = ConnectionMode.values[_prefs.getInt('desktop.mode') ?? 0];
    rotation = _prefs.getInt('desktop.rotation') ?? 0;
    mirror = _prefs.getBool('desktop.mirror') ?? false;
    aspect = OutputAspect.fromName(_prefs.getString('desktop.aspect'));
    aspectFill = _prefs.getBool('desktop.aspectFill') ?? false;
    vcamEnabled = _prefs.getBool('desktop.vcam') ?? true;
    adb.customPath = _prefs.getString('desktop.adbPath');

    textureId = await receiver.textureId();
    await receiver.setTransform(rotation: rotation, mirror: mirror);
    await _applyAspect();
    await refreshSystemCameras();

    await discovery.start();
    _discoverySub = discovery.phones.listen((list) {
      discovered = list;
      notifyListeners();
    });
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _pollStatus());
    if (mode == ConnectionMode.usb) unawaited(refreshAdb());
    notifyListeners();
  }

  // --- connection -----------------------------------------------------------

  /// Handles `--connect=<ip>` and `--usb` startup arguments.
  Future<void> autoConnect(List<String> args) async {
    for (final a in args) {
      if (a.startsWith('--connect=')) {
        setMode(ConnectionMode.wifi);
        await connectWifi(a.substring('--connect='.length));
        return;
      }
      if (a == '--usb') {
        setMode(ConnectionMode.usb);
        await refreshAdb();
        final ready = adbDevices.where((d) => d.ready);
        if (ready.isNotEmpty) await connectUsb(ready.first);
        return;
      }
    }
  }

  void setMode(ConnectionMode m) {
    mode = m;
    _prefs.setInt('desktop.mode', m.index);
    if (m == ConnectionMode.usb) refreshAdb();
    notifyListeners();
  }

  Future<void> connectWifi(String host) async {
    host = host.trim();
    if (host.isEmpty) return;
    await disconnect();
    lastHost = host;
    await _prefs.setString('desktop.host', host);
    connectedVia = ConnectionMode.wifi;
    await _start(host, FcamPorts.streamPort, host, FcamPorts.controlPort, host);
  }

  Future<void> connectUsb(AdbDevice device) async {
    await disconnect();
    adbBusy = true;
    error = null;
    notifyListeners();
    try {
      await adb.forward(device.serial);
      const local = '127.0.0.1';
      final api = PhoneApi(local, FcamPorts.usbControlPort);
      if (!await _reachable(api)) {
        // App not running on the phone: open it and give the camera a moment.
        await adb.launchApp(device.serial);
        for (var i = 0; i < 10 && !await _reachable(api); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
      api.close();
      connectedVia = ConnectionMode.usb;
      await _start(local, FcamPorts.usbStreamPort, local, FcamPorts.usbControlPort,
          '${device.model} (USB)');
    } catch (e) {
      error = e.toString();
    } finally {
      adbBusy = false;
      notifyListeners();
    }
  }

  Future<bool> _reachable(PhoneApi api) async {
    try {
      await api.state();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _start(String streamHost, int streamPort, String apiHost, int apiPort,
      String label) async {
    error = null;
    target = label;
    active = true;
    _api = PhoneApi(apiHost, apiPort);
    // Ask the phone to start streaming so the user doesn't have to touch it.
    try {
      phone = await _api!.update({'streaming': true});
    } catch (_) {
      phone = null;
    }
    await receiver.connect(streamHost, streamPort);
    _phoneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollPhone());
    notifyListeners();
  }

  Future<void> disconnect() async {
    _phoneTimer?.cancel();
    _phoneTimer = null;
    _api?.close();
    _api = null;
    phone = null;
    active = false;
    target = null;
    connectedVia = null;
    await receiver.disconnect();
    notifyListeners();
  }

  Future<void> updatePhone(Map<String, dynamic> changes) async {
    final api = _api;
    if (api == null) return;
    try {
      phone = await api.update(changes);
      error = null;
    } catch (e) {
      error = 'Phone rejected change: $e';
    }
    notifyListeners();
  }

  /// Puts zoom, exposure and focus back to their defaults.
  Future<void> resetOptics() =>
      updatePhone({'zoom': 1.0, 'exposure': 0, 'focusMode': 'auto', 'focusDistance': 0.0});

  // --- snapshot -------------------------------------------------------------

  /// Saves the current preview frame to Pictures\Mini Webcam and returns its path.
  Future<String> takeSnapshot() async {
    final home = Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path;
    final dir = Directory(p.join(home, 'Pictures', 'Mini Webcam'));
    await dir.create(recursive: true);
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = 'mini-webcam-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.png';
    final path = p.join(dir.path, name);
    await receiver.snapshot(path);
    return path;
  }

  Future<void> _pollPhone() async {
    final api = _api;
    if (api == null) return;
    try {
      phone = await api.state();
      notifyListeners();
    } catch (_) {
      // Phone control unreachable; the stream reconnect loop handles the rest.
    }
  }

  Future<void> _pollStatus() async {
    try {
      final previous = status.state;
      status = await receiver.status();
      if (kDebugMode && (status.state != previous || (status.isStreaming && ++_polls % 10 == 0))) {
        debugPrint('[receiver] ${status.state} ${status.message} '
            '${status.codec} ${status.width}x${status.height} '
            'fps=${status.fps.toStringAsFixed(1)} kbps=${status.kbps.toStringAsFixed(0)} '
            'decode=${status.decodeMs.toStringAsFixed(1)}ms errors=${status.decodeErrors} '
            'vcam=${status.vcamActive} ${status.vcamError}');
      }
      notifyListeners();
    } catch (_) {}
  }

  // --- adb ------------------------------------------------------------------

  Future<void> refreshAdb() async {
    adbBusy = true;
    notifyListeners();
    try {
      adbDevices = await adb.devices();
      adbError = null;
    } catch (e) {
      adbDevices = const [];
      adbError = e.toString();
    }
    adbBusy = false;
    notifyListeners();
  }

  Future<void> setAdbPath(String path) async {
    adb.customPath = path;
    await _prefs.setString('desktop.adbPath', path);
    await refreshAdb();
  }

  // --- output ---------------------------------------------------------------

  Future<void> setTransform({int? rotation, bool? mirror}) async {
    this.rotation = rotation ?? this.rotation;
    this.mirror = mirror ?? this.mirror;
    await _prefs.setInt('desktop.rotation', this.rotation);
    await _prefs.setBool('desktop.mirror', this.mirror);
    await receiver.setTransform(rotation: this.rotation, mirror: this.mirror);
    notifyListeners();
  }

  /// Changes the output shape, e.g. 16:9 from a phone held upright.
  Future<void> setAspect({OutputAspect? aspect, bool? fill}) async {
    this.aspect = aspect ?? this.aspect;
    aspectFill = fill ?? aspectFill;
    await _prefs.setString('desktop.aspect', this.aspect.name);
    await _prefs.setBool('desktop.aspectFill', aspectFill);
    await _applyAspect();
    notifyListeners();
  }

  Future<void> _applyAspect() =>
      receiver.setAspect(width: aspect.width, height: aspect.height, fill: aspectFill);

  Future<void> setPreview(bool enabled) async {
    preview = enabled;
    await receiver.setPreview(enabled);
    notifyListeners();
  }

  Future<void> setVirtualCamera(bool enabled) async {
    vcamEnabled = enabled;
    await _prefs.setBool('desktop.vcam', enabled);
    await _syncVirtualCamera();
    notifyListeners();
  }

  Future<void> refreshSystemCameras() async {
    systemCameras = await receiver.listCameras();
    await _syncVirtualCamera();
    notifyListeners();
  }

  /// Only feed the virtual camera when its driver is registered; otherwise no app can
  /// read the frames and the BGR conversion is wasted CPU.
  Future<void> _syncVirtualCamera() =>
      receiver.setVirtualCamera(vcamEnabled && driverInstalled);

  Future<void> installDriver({bool uninstall = false}) async {
    driverBusy = true;
    error = null;
    notifyListeners();
    try {
      if (uninstall) {
        await VirtualCamInstaller.uninstall();
      } else {
        await VirtualCamInstaller.install();
      }
    } catch (e) {
      error = e.toString();
    }
    await refreshSystemCameras();
    driverBusy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _phoneTimer?.cancel();
    _discoverySub?.cancel();
    discovery.stop();
    _api?.close();
    receiver.disconnect();
    super.dispose();
  }
}
