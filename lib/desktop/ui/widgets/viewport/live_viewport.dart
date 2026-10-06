import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../../providers/studio_view_provider.dart';
import '../../theme/studio_theme.dart';
import 'hud_bottom_bar.dart';
import 'hud_top_bar.dart';
import 'rule_of_thirds_grid.dart';
import 'viewport_placeholder.dart';

/// Live video from the native receiver texture with HUD overlays.
class LiveViewport extends StatelessWidget {
  const LiveViewport({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final showGrid = context.select<StudioViewProvider, bool>((v) => v.showGrid);
    final s = c.status;
    final aspect = s.width > 0 && s.height > 0 ? s.width / s.height : 16 / 9;
    final live = c.textureId != null && s.isStreaming && c.preview;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudioColors.border),
        gradient: const RadialGradient(colors: [Color(0xFF1B2636), Color(0xFF0A0E14)], radius: 0.9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: Center(
            child: live
                ? AspectRatio(
                    aspectRatio: aspect,
                    child: Stack(fit: StackFit.expand, children: [
                      Texture(textureId: c.textureId!),
                      if (showGrid) const RuleOfThirdsGrid(),
                    ]),
                  )
                : const ViewportPlaceholder(),
          ),
        ),
        if (s.isStreaming) const Positioned(top: 14, left: 14, right: 14, child: HudTopBar()),
        const Positioned(bottom: 14, left: 14, right: 14, child: HudBottomBar()),
      ]),
    );
  }
}
