/// Ports and constants shared by the phone (server) and desktop (receiver).
///
/// The phone exposes:
///  - [streamPort]  FCAM binary video stream (H.264 or JPEG), see
///    android/.../stream/FcamProtocol.kt for the wire format
///  - [mjpegPort]   MJPEG over HTTP for browsers / OBS / VLC (MJPEG codec only)
///  - [controlPort] JSON control API (settings, features, status)
///  - UDP [discoveryPort] beacons so the desktop finds phones without typing IPs
class FcamPorts {
  static const int streamPort = 8555;
  static const int mjpegPort = 8081;
  static const int controlPort = 8080;
  static const int discoveryPort = 8556;

  /// Local ports used on the PC for `adb forward` (USB mode). Kept away from the
  /// common 8080 so they don't collide with dev servers already running.
  static const int usbStreamPort = 18555;
  static const int usbControlPort = 18080;
}

class FcamDiscovery {
  static const String app = 'mini-webcam';
  static const String probe = 'mini-webcam?probe';
  static const int version = 1;
}
