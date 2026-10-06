import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/protocol.dart';

class AdbDevice {
  const AdbDevice(this.serial, this.model, this.state);
  final String serial;
  final String model;

  /// `device`, `unauthorized`, `offline`...
  final String state;

  bool get ready => state == 'device';
}

/// USB mode: forwards the phone's ports to localhost through adb.
class Adb {
  Adb([this.customPath]);

  String? customPath;
  String? _resolved;

  /// Finds adb: user setting, bundled copy, Android SDK, then PATH.
  Future<String?> locate() async {
    if (_resolved != null && await File(_resolved!).exists()) return _resolved;
    final env = Platform.environment;
    final candidates = <String>[
      if (customPath != null && customPath!.isNotEmpty) customPath!,
      p.join(p.dirname(Platform.resolvedExecutable), 'adb', 'adb.exe'),
      if (env['ANDROID_HOME'] != null)
        p.join(env['ANDROID_HOME']!, 'platform-tools', 'adb.exe'),
      if (env['ANDROID_SDK_ROOT'] != null)
        p.join(env['ANDROID_SDK_ROOT']!, 'platform-tools', 'adb.exe'),
      if (env['LOCALAPPDATA'] != null)
        p.join(env['LOCALAPPDATA']!, 'Android', 'Sdk', 'platform-tools', 'adb.exe'),
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return _resolved = c;
    }
    try {
      final r = await Process.run('where', ['adb']);
      if (r.exitCode == 0) {
        final first = (r.stdout as String).split(RegExp(r'\r?\n')).first.trim();
        if (first.isNotEmpty) return _resolved = first;
      }
    } catch (_) {}
    return null;
  }

  Future<ProcessResult> _run(List<String> args) async {
    final adb = await locate();
    if (adb == null) {
      throw const AdbException(
          'adb not found. Install Android platform-tools or set the adb path.');
    }
    return Process.run(adb, args).timeout(const Duration(seconds: 15));
  }

  /// One `adb devices -l` call gives serial, state and model for every device.
  Future<List<AdbDevice>> devices() async {
    final r = await _run(['devices', '-l']);
    final out = r.stdout as String;
    final list = <AdbDevice>[];
    for (final line in out.split(RegExp(r'\r?\n')).skip(1)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final model = parts
          .firstWhere((t) => t.startsWith('model:'), orElse: () => 'model:${parts[0]}')
          .substring(6)
          .replaceAll('_', ' ');
      list.add(AdbDevice(parts[0], model, parts[1]));
    }
    return list;
  }

  /// Forwards stream + control ports. Returns the localhost ports to use.
  Future<void> forward(String serial) async {
    for (final (local, remote) in [
      (FcamPorts.usbStreamPort, FcamPorts.streamPort),
      (FcamPorts.usbControlPort, FcamPorts.controlPort),
    ]) {
      final r = await _run(['-s', serial, 'forward', 'tcp:$local', 'tcp:$remote']);
      if (r.exitCode != 0) {
        throw AdbException('adb forward failed: ${(r.stderr as String).trim()}');
      }
    }
  }

  Future<void> removeForwards(String serial) async {
    for (final local in [FcamPorts.usbStreamPort, FcamPorts.usbControlPort]) {
      try {
        await _run(['-s', serial, 'forward', '--remove', 'tcp:$local']);
      } catch (_) {}
    }
  }

  /// Opens MiniWebcam on the phone so the user doesn't have to touch it.
  Future<void> launchApp(String serial) async {
    try {
      await _run([
        '-s', serial, 'shell', 'monkey', '-p', 'com.adultcode.miniwebcam',
        '-c', 'android.intent.category.LAUNCHER', '1',
      ]);
    } catch (_) {}
  }
}

class AdbException implements Exception {
  const AdbException(this.message);
  final String message;
  @override
  String toString() => message;
}
