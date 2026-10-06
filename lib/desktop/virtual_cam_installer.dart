import 'dart:io';

import 'package:path/path.dart' as p;

/// Registers / unregisters the "Mini Webcam" DirectShow camera so apps like
/// Zoom, Teams, Meet (in Chrome/Edge), Discord and OBS can pick it.
///
/// The camera DLL (our softcam build, see windows/third_party/softcam) is copied
/// to %LOCALAPPDATA%\MiniWebcam first, so the registration keeps working when
/// the app folder moves, and when the portable build runs from a temp folder.
/// Registration needs admin rights, so Windows shows one UAC prompt.
class VirtualCamInstaller {
  /// Name other apps show in their camera list.
  static const deviceName = 'Mini Webcam';

  static String get _bundledDll =>
      p.join(p.dirname(Platform.resolvedExecutable), 'softcam.dll');

  static String get _installDir => p.join(
      Platform.environment['LOCALAPPDATA'] ?? p.dirname(Platform.resolvedExecutable),
      'MiniWebcam');

  static String get _installedDll => p.join(_installDir, 'mini-webcam-camera.dll');

  /// Earlier builds installed a third-party DLL under this name ("AWC Virtual Cam").
  static String get _legacyDll => p.join(_installDir, 'softcam.dll');

  static Future<void> install() async {
    final source = File(_bundledDll);
    if (!await source.exists()) {
      throw const FileSystemException('softcam.dll is missing next to mini-webcam.exe');
    }
    await Directory(_installDir).create(recursive: true);
    try {
      await source.copy(_installedDll);
    } on FileSystemException {
      throw const FileSystemException(
          'The camera is in use. Close apps that use it (Zoom, Teams, OBS, browser) and retry.');
    }
    await _elevated([
      if (await File(_legacyDll).exists()) _regsvr32(['/u', _legacyDll], check: false),
      _regsvr32([_installedDll]),
    ]);
  }

  static Future<void> uninstall() async {
    await _elevated([
      if (await File(_legacyDll).exists()) _regsvr32(['/u', _legacyDll], check: false),
      if (await File(_installedDll).exists()) _regsvr32(['/u', _installedDll]),
    ]);
  }

  /// One PowerShell line that runs regsvr32 silently and, if [check], fails
  /// the script with regsvr32's exit code.
  static String _regsvr32(List<String> args, {bool check = true}) {
    final quoted = args
        .map((a) => a.startsWith('/') ? "'$a'" : "'\"${a.replaceAll("'", "''")}\"'")
        .join(',');
    final run = "\$p = Start-Process regsvr32.exe -ArgumentList '/s',$quoted -Wait -PassThru";
    return check ? '$run; if (\$p.ExitCode -ne 0) { exit \$p.ExitCode }' : run;
  }

  /// Runs [lines] in a single elevated PowerShell (one UAC prompt).
  static Future<void> _elevated(List<String> lines) async {
    if (lines.isEmpty) return;
    final script = File(p.join(Directory.systemTemp.path, 'mini-webcam-camera-$pid.ps1'));
    await script.writeAsString([...lines, 'exit 0'].join('\n'));
    try {
      final launcher = "\$p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru "
          "-WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass',"
          "'-File','\"${script.path.replaceAll("'", "''")}\"'; exit \$p.ExitCode";
      final r = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', launcher],
      );
      if (r.exitCode != 0) {
        throw ProcessException('regsvr32', const [],
            'Camera registration failed (code ${r.exitCode}). Was the admin prompt declined?',
            r.exitCode);
      }
    } finally {
      try {
        await script.delete();
      } catch (_) {}
    }
  }
}
