import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'desktop/providers/desktop_provider.dart';
import 'desktop/providers/studio_view_provider.dart';
import 'desktop/ui/screens/desktop_home_screen.dart';
import 'desktop/ui/theme/studio_theme.dart';
import 'phone/providers/blackout_provider.dart';
import 'phone/providers/phone_provider.dart';
import 'phone/providers/phone_view_provider.dart';
import 'phone/ui/screens/phone_home_screen.dart';
import 'phone/ui/theme/oled_theme.dart';

/// Root widget. Picks the phone or desktop role and installs its providers.
class MiniWebcamApp extends StatelessWidget {
  const MiniWebcamApp({super.key, this.args = const []});

  final List<String> args;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Mini Webcam',
      debugShowCheckedModeBanner: false,
      theme: Platform.isAndroid ? buildOledTheme() : buildStudioTheme(),
      home: Platform.isAndroid ? const PhoneHomeScreen() : const DesktopHomeScreen(),
    );
    return Platform.isAndroid ? _phoneProviders(app) : _desktopProviders(app);
  }

  Widget _phoneProviders(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PhoneProvider()..init()),
          ChangeNotifierProxyProvider<PhoneProvider, BlackoutProvider>(
            create: (_) => BlackoutProvider(),
            update: (_, phone, blackout) => blackout!..updateStreaming(phone.streaming),
          ),
          ChangeNotifierProvider(create: (_) => PhoneViewProvider()),
        ],
        child: child,
      );

  Widget _desktopProviders(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DesktopProvider()..start(args)),
          ChangeNotifierProvider(create: (_) => StudioViewProvider()),
        ],
        child: child,
      );
}
