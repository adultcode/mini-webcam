import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/desktop_provider.dart';
import '../../services/virtual_cam_installer.dart';
import 'section_card.dart';

/// Virtual camera on/off, driver install state and status.
class VirtualCameraCard extends StatelessWidget {
  const VirtualCameraCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final s = c.status;
    const name = VirtualCamInstaller.deviceName;
    final String detail;
    if (!c.driverInstalled) {
      detail = 'Install the driver once so other apps can see "$name".';
    } else if (s.vcamError.isNotEmpty) {
      detail = s.vcamError;
    } else if (s.vcamAppConnected) {
      detail = 'In use by an app.';
    } else if (s.vcamActive) {
      detail = 'Ready. Pick "$name" in Zoom, Teams, OBS...';
    } else {
      detail = c.vcamEnabled ? 'Waiting for video.' : 'Off.';
    }

    return SectionCard(
      title: 'Virtual webcam',
      trailing: Switch(
        value: c.vcamEnabled && c.driverInstalled,
        onChanged: c.driverInstalled ? c.setVirtualCamera : null,
      ),
      children: [
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Row(children: [
          if (!c.driverInstalled)
            FilledButton.icon(
              onPressed: c.driverBusy ? null : () => c.installDriver(),
              icon: const Icon(Icons.download),
              label: const Text('Install driver'),
            )
          else
            TextButton(
              onPressed: c.driverBusy ? null : () => c.installDriver(uninstall: true),
              child: const Text('Uninstall driver'),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Re-check',
            onPressed: c.refreshSystemCameras,
            icon: const Icon(Icons.refresh),
          ),
        ]),
      ],
    );
  }
}
