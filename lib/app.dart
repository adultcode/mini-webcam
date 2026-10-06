import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'desktop/providers/desktop_provider.dart';
import 'desktop/ui/screens/desktop_home_screen.dart';
import 'phone/providers/blackout_provider.dart';
import 'phone/providers/phone_provider.dart';
import 'phone/ui/screens/phone_home_screen.dart';

/// Root widget. Picks the phone or desktop role and installs its providers.
class MiniWebcamApp extends StatelessWidget {
  const MiniWebcamApp({super.key, this.args = const []});

  final List<String> args;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Mini Webcam',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
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
        ],
        child: child,
      );

  Widget _desktopProviders(Widget child) => ChangeNotifierProvider(
        create: (_) => DesktopProvider()..start(args),
        child: child,
      );
}
