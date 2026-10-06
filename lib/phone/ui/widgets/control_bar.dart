import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/blackout_provider.dart';
import '../../providers/phone_provider.dart';
import 'round_icon_button.dart';
import 'settings_sheet.dart';
import 'stream_button.dart';
import 'zoom_bar.dart';

/// Bottom controls: zoom, camera switch, torch, stream, screen off, settings.
class ControlBar extends StatelessWidget {
  const ControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final s = phone.settings;
    final f = phone.features;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZoomBar(),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RoundIconButton(
                  icon: Icons.cameraswitch_outlined,
                  tooltip: 'Switch camera',
                  onTap: f.cameras.length > 1
                      ? () => phone.applyChanges({'camera': s.camera == 'back' ? 'front' : 'back'})
                      : null,
                ),
                RoundIconButton(
                  icon: s.torch ? Icons.flashlight_on : Icons.flashlight_off_outlined,
                  tooltip: 'Torch',
                  active: s.torch,
                  onTap: f.hasFlash ? () => phone.applyChanges({'torch': !s.torch}) : null,
                ),
                const StreamButton(),
                RoundIconButton(
                  icon: Icons.dark_mode_outlined,
                  tooltip: 'Screen off (keeps streaming)',
                  onTap: context.read<BlackoutProvider>().blackOut,
                ),
                RoundIconButton(
                  icon: Icons.tune,
                  tooltip: 'Settings',
                  onTap: () => SettingsSheet.show(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
