import 'dart:io';

import 'package:flutter/material.dart';

import 'desktop/desktop_home.dart';
import 'phone/phone_home.dart';
import 'shared/theme.dart';

/// One codebase, two roles:
///  - Android: turns the phone into a camera server (capture + hardware encode + stream)
///  - Windows: receives the stream and exposes it as a virtual webcam
///
/// Desktop command line: `mini-webcam.exe --connect=192.168.1.20` (Wi-Fi) or
/// `mini-webcam.exe --usb` (first adb device) to connect on startup.
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MiniWebcamApp(args: args));
}

class MiniWebcamApp extends StatelessWidget {
  const MiniWebcamApp({super.key, this.args = const []});

  final List<String> args;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini Webcam',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Platform.isAndroid ? const PhoneHome() : DesktopHome(args: args),
    );
  }
}
