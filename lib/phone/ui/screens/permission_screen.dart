import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/phone_provider.dart';

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
            const Icon(Icons.no_photography_outlined, size: 56),
            const SizedBox(height: 16),
            const Text('Camera permission is required to use the phone as a webcam.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: context.read<PhoneProvider>().retryPermission,
              child: const Text('Grant permission'),
            ),
          ]),
        ),
      ),
    );
  }
}
