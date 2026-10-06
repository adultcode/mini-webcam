import 'package:flutter/material.dart';

import '../../theme/studio_theme.dart';
import '../common/inset_panel.dart';
import '../common/studio_button.dart';

/// One connectable phone (discovered on Wi-Fi or listed by adb).
class DeviceListTile extends StatelessWidget {
  const DeviceListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onConnect,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InsetPanel(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          Icon(icon, size: 18, color: StudioColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(subtitle, overflow: TextOverflow.ellipsis, style: StudioText.caption),
            ]),
          ),
          StudioButton(label: 'Connect', style: StudioButtonStyle.primary, onPressed: onConnect),
        ]),
      ),
    );
  }
}
