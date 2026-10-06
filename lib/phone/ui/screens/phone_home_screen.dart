import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/blackout_provider.dart';
import '../../providers/phone_provider.dart';
import '../widgets/blackout_overlay.dart';
import '../widgets/camera_preview.dart';
import '../widgets/control_bar.dart';
import '../widgets/status_overlay.dart';
import 'permission_screen.dart';

/// Phone main screen: live preview with status on top and controls below.
class PhoneHomeScreen extends StatelessWidget {
  const PhoneHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final denied = context.select<PhoneProvider, bool>((p) => p.permissionDenied);
    if (denied) return const PermissionScreen();

    final blackout = context.select<BlackoutProvider, bool>((b) => b.active);
    return Listener(
      // Any touch wakes the screen and restarts the auto blackout countdown.
      onPointerDown: (_) => context.read<BlackoutProvider>().userActivity(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CameraPreview(),
            const StatusOverlay(),
            const Align(alignment: Alignment.bottomCenter, child: ControlBar()),
            if (blackout) const BlackoutOverlay(),
          ],
        ),
      ),
    );
  }
}
