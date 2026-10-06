import 'dart:io';

import 'package:path/path.dart' as p;

/// Registers / unregisters the Softcam DirectShow filter so that apps like Zoom,
/// Teams, Meet (in Chrome/Edge), Discord and OBS can pick "DirectShow Softcam".
///
/// The DLL is copied to %LOCALAPPDATA%\MiniWebcam first so the registration keeps
/// working when the app folder is moved or updated. Registration needs admin
/// rights once, so Windows shows a UAC prompt.
class VirtualCamInstaller {
  static const deviceName = 'DirectShow Softcam';

  static String get _bundledDll =>
      p.join(p.dirname(Platform.resolvedExecutable), 'softcam.dll');

  static String get _installedDll => p.join(
      Platform.environment['LOCALAPPDATA'] ?? p.dirname(Platform.resolvedExecutable),
      'MiniWebcam',
      'softcam.dll');

  static Future<void> install() async {
    final source = File(_bundledDll);
    if (!await source.exists()) {
      throw const FileSystemException('softcam.dll is missing next to mini-webcam.exe');
    }
    final target = File(_installedDll);
    await target.parent.create(recursive: true);
    try {
      await source.copy(target.path);
    } on FileSystemException {
      // Already registered and loaded by some app; the existing copy is fine.
      if (!await target.exists()) rethrow;
    }
    await _regsvr32(['/s', target.path]);
  }

  static Future<void> uninstall() async {
    final target = File(_installedDll);
    if (!await target.exists()) return;
    await _regsvr32(['/u', '/s', target.path]);
  }

  static Future<void> _regsvr32(List<String> args) async {
    // PowerShell single-quoted strings; paths get inner double quotes for regsvr32.
    final quoted = args
        .map((a) => a.startsWith('/') ? "'$a'" : "'\"${a.replaceAll("'", "''")}\"'")
        .join(',');
    final script = r'$p = Start-Process -FilePath regsvr32.exe -Verb RunAs -Wait -PassThru '
        '-ArgumentList $quoted; exit \$p.ExitCode';
    final r = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
    );
    if (r.exitCode != 0) {
      throw ProcessException('regsvr32', args,
          'regsvr32 failed (exit ${r.exitCode}). Was the admin prompt declined?', r.exitCode);
    }
  }
}
