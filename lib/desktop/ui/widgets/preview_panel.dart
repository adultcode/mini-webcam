import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/desktop_provider.dart';

/// Native receiver texture, or a placeholder when there is nothing to show.
class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final s = c.status;
    final aspect = s.width > 0 && s.height > 0 ? s.width / s.height : 16 / 9;
    final showVideo = c.textureId != null && s.isStreaming && c.preview;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: showVideo
            ? AspectRatio(aspectRatio: aspect, child: Texture(textureId: c.textureId!))
            : _Placeholder(state: s.state, message: s.message, idle: s.isIdle),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.state, required this.message, required this.idle});

  final String state;
  final String message;
  final bool idle;

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      'streaming' => 'Preview hidden',
      'connecting' || 'reconnecting' => message,
      _ => 'Connect to your phone to start',
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(idle ? Icons.phone_android : Icons.hourglass_top, size: 48, color: Colors.white24),
      const SizedBox(height: 12),
      Text(text, style: const TextStyle(color: Colors.white54)),
    ]);
  }
}
