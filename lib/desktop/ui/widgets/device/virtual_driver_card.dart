import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../../services/virtual_cam_installer.dart';
import '../../theme/studio_theme.dart';
import '../common/inset_panel.dart';
import '../common/studio_button.dart';
import '../common/studio_card.dart';

/// Virtual camera output: on/off, live status and driver install.
class VirtualDriverCard extends StatelessWidget {
  const VirtualDriverCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final s = c.status;
    const name = VirtualCamInstaller.deviceName;
    final (icon, color, headline, detail) = !c.driverInstalled
        ? (Icons.info_outline, StudioColors.warning, 'Driver not installed',
            'Install it once so apps can list "$name". Windows asks for admin rights.')
        : s.vcamError.isNotEmpty
            ? (Icons.error_outline, StudioColors.danger, 'Camera error', s.vcamError)
            : s.vcamAppConnected
                ? (Icons.check_circle_outline, StudioColors.success, 'In use by an app',
                    'Video is being delivered to "$name".')
                : s.vcamActive
                    ? (Icons.check_circle_outline, StudioColors.success, 'Ready',
                        'Pick "$name" in Zoom, Teams, Meet or OBS.')
                    : (Icons.pause_circle_outline, StudioColors.textSecondary,
                        c.vcamEnabled ? 'Waiting for video' : 'Off',
                        c.vcamEnabled ? 'Connect a phone to feed the camera.' : 'Turn on to feed "$name".');

    return StudioCard(
      icon: Icons.videocam_outlined,
      title: 'Virtual Driver',
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: c.vcamEnabled && c.driverInstalled,
          onChanged: c.driverInstalled ? c.setVirtualCamera : null,
        ),
      ),
      children: [
        InsetPanel(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(headline, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
            ]),
            const SizedBox(height: 6),
            Text(detail, style: StudioText.caption),
          ]),
        ),
        Row(children: [
          const Icon(Icons.verified_user_outlined, size: 14, color: StudioColors.accent),
          const SizedBox(width: 6),
          const Expanded(child: Text('$name (DirectShow)', style: StudioText.caption)),
          IconButton(
            tooltip: 'Re-check',
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            color: StudioColors.textSecondary,
            onPressed: c.refreshSystemCameras,
            icon: const Icon(Icons.refresh),
          ),
        ]),
        if (!c.driverInstalled)
          StudioButton(
            label: 'Install driver',
            icon: Icons.download,
            style: StudioButtonStyle.primary,
            busy: c.driverBusy,
            onPressed: c.installDriver,
          )
        else
          StudioButton(
            label: 'Uninstall driver',
            icon: Icons.delete_outline,
            busy: c.driverBusy,
            onPressed: () => c.installDriver(uninstall: true),
          ),
      ],
    );
  }
}
