# Mini Webcam

Use your Android phone as a webcam on Windows. A Flutter rewrite of
[Android-Webcam-Project](https://github.com/soubhagyajit/Android-Webcam-Project), with a new
native streaming pipeline on both sides.

| Platform | Role |
|---|---|
| Android | Camera server: Camera2 capture, hardware H.264 encoding, network stream |
| Windows | Receiver: native decoding, live preview, and the **Mini Webcam** virtual camera for Zoom, Teams, Meet, OBS and Discord |

## Download

Every [release](https://github.com/adultcode/mini-webcam/releases) contains:

| File | Use |
|---|---|
| `mini-webcam-<version>-android-universal.apk` | Works on every phone |
| `mini-webcam-<version>-android-arm64-v8a.apk` | Most modern phones (smaller download) |
| `mini-webcam-<version>-android-armeabi-v7a.apk` | Older 32-bit phones |
| `mini-webcam-<version>-android-x86_64.apk` | Emulators and x86 devices |
| `mini-webcam-<version>-windows-x64-portable.exe` | Single file. Double-click to run; nothing is installed |
| `mini-webcam-<version>-windows-x64.zip` | Same app as a folder. Extract it and run `mini-webcam.exe` |

Each platform also ships a `SHA256SUMS.txt` file.

## Usage

1. Install the APK on the phone and open it. Grant the camera permission.
2. Start Mini Webcam on the PC.
3. Connect:
   - **Wi-Fi**: the phone shows up in the list on its own. You can also type its IP.
   - **USB**: turn on USB debugging, plug in the phone, and click **Connect**. If the app is not running on the phone, the PC opens it over adb. This needs adb: either Android platform-tools, or `adb\adb.exe` placed next to the app.
4. The PC starts the phone stream itself; you don't need to touch the phone.
5. Click **Install driver** once (Windows asks for admin rights). Then pick **Mini Webcam** as the camera in your video app. Keep the phone unlocked with the app open: Android stops the camera when the screen turns off.

Command line: `mini-webcam.exe --usb` or `mini-webcam.exe --connect=192.168.1.20` connects at startup.

## Features

- Hardware H.264 from the phone: `MediaCodec` reads straight from the camera surface, so frames never pass through the CPU or Dart.
- One compact binary stream (FCAM) for H.264 or JPEG. Each viewer has its own queue, so one slow client never delays the others.
- Windows decoding uses the built-in Media Foundation H.264 decoder and WIC for JPEG. No FFmpeg is needed.
- Native C++ frame path on Windows to the Flutter texture and the virtual camera. Dart only reads stats.
- Automatic phone discovery on the LAN (UDP). In USB mode, ports are forwarded and the phone app is opened for you.
- Change settings from the phone or the PC: camera, resolution, fps, codec, bitrate, zoom, torch, exposure and manual focus.
- Rotate (0/90/180/270) or mirror the picture on the PC.
- MJPEG mode for browsers, OBS and VLC: `http://<phone-ip>:8081/video`.
- On the phone: tap to focus, pinch to zoom, and the screen blacks out while streaming to save battery.

## Ports (phone)

| Port | Use |
|---|---|
| 8555 | FCAM video stream (format in `android/.../stream/FcamProtocol.kt`) |
| 8080 | JSON control API: `GET /api/info`, `GET/POST /api/settings`, `POST /api/focus`, `GET /api/status` |
| 8081 | MJPEG `/video` and `/snapshot.jpg` (only when the codec is set to MJPEG) |
| 8556/udp | Discovery |

## Project layout

```
lib/
  main.dart                    picks the phone or desktop UI
  shared/                      models, ports, theme
  phone/                       phone UI, control HTTP server, discovery beacon
  desktop/                     receiver UI, adb, discovery, phone API client, driver installer
android/app/src/main/kotlin/com/adultcode/miniwebcam/
  CameraPlugin.kt              method channel "miniwebcam/camera"
  camera/CameraEngine.kt       Camera2 session, preview texture, 3A controls
  stream/H264Encoder.kt        MediaCodec surface encoder
  stream/JpegEncoder.kt        YUV to JPEG for MJPEG mode
  stream/StreamHub.kt          FCAM and MJPEG servers, per-client queues
windows/runner/fcam/
  receiver.cpp                 socket, FCAM parser, transform, texture
  decoders.cpp                 Media Foundation H.264, WIC JPEG, NV12 to RGBA
  virtual_camera.cpp           softcam.dll loader and sender thread
  receiver_plugin.cpp          method channel "miniwebcam/receiver"
windows/packaging/             portable exe manifest and self-extractor config
windows/third_party/softcam/   build_softcam.ps1: builds the camera DLL from tshino/softcam (MIT)
```

## Building

```
flutter build apk --release --split-per-abi
flutter build windows --release
```

Release builds are signed with the key described in `android/key.properties`. This file is not committed:

```
storeFile=/absolute/path/to/keystore
storePassword=...
keyAlias=...
keyPassword=...
```

Without that file, release APKs are signed with the debug key.

## Releases (CI)

`.github/workflows/release.yml` runs when a GitHub release is published. Tags must look like `v1.2.3`. The workflow builds every file listed under [Download](#download) and attaches them to the release. You can also run it by hand from the Actions tab; the files then appear as workflow artifacts.

Required repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

## Known limits

- Streaming stops when the phone app goes to the background, because Android blocks camera access for background apps. Keep the app open; the blackout mode saves power.
- The virtual camera is 64-bit, so 32-bit apps won't list it.
- The control API has no authentication. Use it only on networks you trust.

## Credits

- [Android-Webcam-Project](https://github.com/soubhagyajit/Android-Webcam-Project), the original idea and design
- [Softcam](https://github.com/tshino/softcam), the DirectShow virtual camera our driver is built from (MIT). The Windows build compiles it from source, renamed to Mini Webcam with its own CLSID and a static runtime.

## License

The original project is GPL-3.0. This rewrite derives from it and is distributed under the same license.
