import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/blackout_provider.dart';
import '../../providers/phone_provider.dart';
import '../widgets/controls/action_deck.dart';
import '../widgets/controls/quality_chips.dart';
import '../widgets/controls/zoom_pill.dart';
import '../widgets/header/phone_header.dart';
import '../widgets/hud/error_banner.dart';
import '../widgets/hud/stream_chips.dart';
import '../widgets/overlays/blackout_overlay.dart';
import '../widgets/viewport/camera_viewport.dart';
import '../widgets/viewport/framing_guides.dart';
import '../widgets/viewport/viewport_shade.dart';
import 'permission_screen.dart';

/// OLED studio: full-screen viewfinder with floating glass controls.
class PhoneHomeScreen extends StatelessWidget {
  const PhoneHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final denied = context.select<PhoneProvider, bool>((p) => p.permissionDenied);
    if (denied) return const PermissionScreen();
    final blackout = context.select<BlackoutProvider, bool>((b) => b.active);

    return Listener(
      // Any touch wakes the screen and restarts the auto-sleep countdown.
      onPointerDown: (_) => context.read<BlackoutProvider>().userActivity(),
      child: Scaffold(
        body: Stack(fit: StackFit.expand, children: [
          const CameraViewport(),
          const FramingGuides(),
          const ViewportShade(),
          const SafeArea(
            child: Column(children: [
              PhoneHeader(),
              ErrorBanner(),
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(padding: EdgeInsets.all(16), child: StreamChips()),
                ),
              ),
              ZoomPill(),
              SizedBox(height: 10),
              QualityChips(),
              SizedBox(height: 10),
              Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 12), child: ActionDeck()),
            ]),
          ),
          if (blackout) const BlackoutOverlay(),
        ]),
      ),
    );
  }
}
