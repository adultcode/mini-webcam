import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';

/// Centre pill describing the link to the phone, e.g. "Live over USB · RMX3760".
class LinkStatusPill extends StatelessWidget {
  const LinkStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final via = switch (c.connectedVia) {
      ConnectionMode.usb => 'USB',
      ConnectionMode.wifi => 'Wi-Fi',
      null => '',
    };
    final (dot, label, detail) = switch (c.status.state) {
      'streaming' => (StudioColors.success, 'Live over $via', c.status.device),
      'connecting' => (StudioColors.warning, 'Connecting', c.target ?? ''),
      'reconnecting' => (StudioColors.warning, 'Reconnecting', c.target ?? ''),
      'error' => (StudioColors.danger, 'Error', c.status.message),
      _ => (StudioColors.textMuted, 'No phone connected', ''),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x990F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StudioColors.divider),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: StudioText.caption),
        if (detail.isNotEmpty) ...[
          const Text(' · ', style: StudioText.caption),
          Text(detail,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0))),
        ],
      ]),
    );
  }
}
