import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../../services/receiver_channel.dart';
import '../../theme/studio_theme.dart';
import '../common/draft_slider.dart';
import '../common/inset_panel.dart';
import '../common/pill_selector.dart';
import '../common/studio_button.dart';
import '../common/studio_card.dart';

/// Background blur or replacement, computed on the PC with person
/// segmentation before frames reach the preview and the virtual camera.
class BackgroundCard extends StatelessWidget {
  const BackgroundCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final mode = c.background;
    final status = c.status;

    return StudioCard(
      icon: Icons.blur_on,
      title: 'Background',
      children: [
        PillSelector<BackgroundMode>(
          options: const [
            PillOption(BackgroundMode.off, 'Off'),
            PillOption(BackgroundMode.blur, 'Blur', icon: Icons.blur_on),
            PillOption(BackgroundMode.image, 'Image', icon: Icons.image_outlined),
          ],
          selected: mode,
          onChanged: c.setBackgroundMode,
        ),
        if (mode == BackgroundMode.blur)
          DraftSlider(
            id: 'background.blur',
            label: 'Blur Strength',
            value: c.blurStrength.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            format: (v) => '${v.round()}%',
            onCommit: (v) => c.setBlurStrength(v.round()),
          ),
        if (mode == BackgroundMode.image)
          Row(children: [
            Expanded(
              child: Text(
                c.backgroundImage.isEmpty ? 'No picture chosen' : p.basename(c.backgroundImage),
                style: StudioText.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            StudioButton(
              label: 'Choose...',
              icon: Icons.folder_open,
              onPressed: c.pickBackgroundImage,
            ),
          ]),
        if (mode != BackgroundMode.off) _StatusPanel(status: status),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status});

  final ReceiverStatus status;

  @override
  Widget build(BuildContext context) {
    final failed = status.bgError.isNotEmpty;
    final (text, color) = failed
        ? (status.bgError, StudioColors.danger)
        : status.bgActive
            ? ('${status.bgMs.toStringAsFixed(1)} ms / frame', StudioColors.success)
            : ('Waiting for video', StudioColors.textMuted);

    return InsetPanel(
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        const Icon(Icons.person_outline, size: 14, color: StudioColors.accent),
        const SizedBox(width: 6),
        const Expanded(child: Text('Person segmentation (ONNX)', style: StudioText.caption)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontFamily: StudioText.mono, fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }
}
