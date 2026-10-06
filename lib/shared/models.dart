/// Camera settings, mirrored by CameraSettings.kt on Android.
class CameraSettings {
  const CameraSettings({
    this.camera = 'back',
    this.resolution = '1280x720',
    this.fps = 30,
    this.codec = 'h264',
    this.bitrate = 6000000,
    this.jpegQuality = 75,
    this.zoom = 1,
    this.torch = false,
    this.focusMode = 'auto',
    this.focusDistance = 0,
    this.exposure = 0,
  });

  final String camera;
  final String resolution;
  final int fps;
  final String codec;
  final int bitrate;
  final int jpegQuality;
  final double zoom;
  final bool torch;
  final String focusMode;
  final double focusDistance;
  final int exposure;

  factory CameraSettings.fromMap(Map<dynamic, dynamic> m) => CameraSettings(
        camera: m['camera'] as String? ?? 'back',
        resolution: m['resolution'] as String? ?? '1280x720',
        fps: (m['fps'] as num?)?.toInt() ?? 30,
        codec: m['codec'] as String? ?? 'h264',
        bitrate: (m['bitrate'] as num?)?.toInt() ?? 6000000,
        jpegQuality: (m['jpegQuality'] as num?)?.toInt() ?? 75,
        zoom: (m['zoom'] as num?)?.toDouble() ?? 1,
        torch: m['torch'] as bool? ?? false,
        focusMode: m['focusMode'] as String? ?? 'auto',
        focusDistance: (m['focusDistance'] as num?)?.toDouble() ?? 0,
        exposure: (m['exposure'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'camera': camera,
        'resolution': resolution,
        'fps': fps,
        'codec': codec,
        'bitrate': bitrate,
        'jpegQuality': jpegQuality,
        'zoom': zoom,
        'torch': torch,
        'focusMode': focusMode,
        'focusDistance': focusDistance,
        'exposure': exposure,
      };
}

/// What the currently selected phone camera supports.
class CameraFeatures {
  const CameraFeatures({
    this.cameras = const ['back'],
    this.resolutions = const ['1280x720'],
    this.fps = const [30],
    this.zoomMin = 1,
    this.zoomMax = 1,
    this.hasFlash = false,
    this.manualFocus = false,
    this.exposureMin = 0,
    this.exposureMax = 0,
    this.exposureStep = 0,
    this.sensorOrientation = 90,
    this.frontFacing = false,
  });

  final List<String> cameras;
  final List<String> resolutions;
  final List<int> fps;
  final double zoomMin;
  final double zoomMax;
  final bool hasFlash;
  final bool manualFocus;
  final int exposureMin;
  final int exposureMax;
  final double exposureStep;
  final int sensorOrientation;
  final bool frontFacing;

  factory CameraFeatures.fromMap(Map<dynamic, dynamic> m) => CameraFeatures(
        cameras: (m['cameras'] as List?)?.cast<String>() ?? const ['back'],
        resolutions:
            (m['resolutions'] as List?)?.cast<String>() ?? const ['1280x720'],
        fps: (m['fps'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const [30],
        zoomMin: (m['zoomMin'] as num?)?.toDouble() ?? 1,
        zoomMax: (m['zoomMax'] as num?)?.toDouble() ?? 1,
        hasFlash: m['hasFlash'] as bool? ?? false,
        manualFocus: m['manualFocus'] as bool? ?? false,
        exposureMin: (m['exposureMin'] as num?)?.toInt() ?? 0,
        exposureMax: (m['exposureMax'] as num?)?.toInt() ?? 0,
        exposureStep: (m['exposureStep'] as num?)?.toDouble() ?? 0,
        sensorOrientation: (m['sensorOrientation'] as num?)?.toInt() ?? 90,
        frontFacing: m['frontFacing'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'cameras': cameras,
        'resolutions': resolutions,
        'fps': fps,
        'zoomMin': zoomMin,
        'zoomMax': zoomMax,
        'hasFlash': hasFlash,
        'manualFocus': manualFocus,
        'exposureMin': exposureMin,
        'exposureMax': exposureMax,
        'exposureStep': exposureStep,
        'sensorOrientation': sensorOrientation,
        'frontFacing': frontFacing,
      };
}

String resolutionLabel(String res) {
  final h = int.tryParse(res.split('x').last) ?? 0;
  return switch (h) {
    2160 => '4K  ($res)',
    1440 => '1440p  ($res)',
    1080 => '1080p  ($res)',
    720 => '720p  ($res)',
    _ => res,
  };
}

const bitrateOptions = <int>[
  1000000,
  2000000,
  4000000,
  6000000,
  8000000,
  12000000,
  20000000,
];

String formatBitrate(int bps) => bps >= 1000000
    ? '${(bps / 1000000).toStringAsFixed(bps % 1000000 == 0 ? 0 : 1)} Mbps'
    : '${bps ~/ 1000} kbps';
