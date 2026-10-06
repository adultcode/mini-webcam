import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../../providers/studio_view_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/hud_icon_button.dart';
import 'snapshot_button.dart';

/// Viewport toolbar: framing tools on the left, snapshot in the centre.
class HudBottomBar extends StatelessWidget {
  const HudBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final view = context.watch<StudioViewProvider>();
    return Stack(alignment: Alignment.center, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xB3000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xB3334155)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            HudIconButton(
              icon: Icons.grid_on,
              tooltip: 'Rule-of-thirds grid (preview only)',
              active: view.showGrid,
              onPressed: view.toggleGrid,
            ),
            HudIconButton(
              icon: Icons.flip,
              tooltip: 'Mirror video',
              active: c.mirror,
              onPressed: () => c.setTransform(mirror: !c.mirror),
            ),
            HudIconButton(
              icon: Icons.rotate_right,
              tooltip: 'Rotate 90°',
              onPressed: () => c.setTransform(rotation: (c.rotation + 90) % 360),
            ),
          ]),
        ),
      ),
      if (c.status.isStreaming && c.preview) const SnapshotButton(),
      if (c.status.isStreaming && !c.preview)
        const Text('Turn on Live Preview to take snapshots', style: StudioText.caption),
    ]);
  }
}
