import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/phone_provider.dart';
import '../theme/oled_theme.dart';

/// Shown until the camera permission is granted.
class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/logo.png', height: 72),
            const SizedBox(height: 24),
            const Text('Camera access needed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Mini Webcam uses the camera to stream video to your PC.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: OledColors.dimText)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: context.read<PhoneProvider>().retryPermission,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Allow camera'),
            ),
          ]),
        ),
      ),
    );
  }
}
