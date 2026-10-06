import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../common/deck_button.dart';
import '../common/glass_container.dart';
import '../settings/settings_sheet.dart';
import 'stream_trigger.dart';

/// Bottom deck: camera switch, torch, stream, focus mode, settings.
class ActionDeck extends StatelessWidget {
  const ActionDeck({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final s = phone.settings;
    final f = phone.features;
    final manual = s.focusMode == 'manual';

    return GlassContainer(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DeckButton(
            icon: Icons.flip_camera_android_outlined,
            tooltip: 'Switch camera',
            onPressed: f.cameras.length > 1
                ? () => phone.applyChanges({'camera': s.camera == 'back' ? 'front' : 'back'})
                : null,
          ),
          DeckButton(
            icon: s.torch ? Icons.flashlight_on : Icons.flashlight_off_outlined,
            tooltip: 'Torch (fill light)',
            active: s.torch,
            onPressed: f.hasFlash ? () => phone.applyChanges({'torch': !s.torch}) : null,
          ),
          const StreamTrigger(),
          DeckButton(
            icon: manual ? Icons.center_focus_weak : Icons.center_focus_strong_outlined,
            tooltip: manual ? 'Manual focus (tap for auto)' : 'Autofocus (tap for manual)',
            active: manual,
            onPressed: f.manualFocus
                ? () => phone.applyChanges({'focusMode': manual ? 'auto' : 'manual'})
                : null,
          ),
          DeckButton(
            icon: Icons.tune,
            tooltip: 'Settings',
            accent: true,
            onPressed: () => SettingsSheet.show(context),
          ),
        ],
      ),
    );
  }
}
