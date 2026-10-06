import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/studio_button.dart';
import 'adb_path_dialog.dart';
import 'device_list_tile.dart';

/// Phones attached over USB (adb), with refresh and adb path setup.
class UsbConnectList extends StatelessWidget {
  const UsbConnectList({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Enable USB debugging on the phone, plug it in and accept the prompt.',
              style: StudioText.caption),
        ),
        if (c.adbError != null) ...[
          Text(c.adbError!, style: const TextStyle(fontSize: 11, color: StudioColors.warning)),
          const SizedBox(height: 6),
        ],
        for (final d in c.adbDevices)
          DeviceListTile(
            icon: Icons.usb,
            title: d.model,
            subtitle: d.ready ? d.serial : '${d.serial} · ${d.state} (check the phone)',
            onConnect: d.ready && !c.adbBusy ? () => c.connectUsb(d) : null,
          ),
        if (c.adbDevices.isEmpty && c.adbError == null && !c.adbBusy)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('No devices found.', style: StudioText.caption),
          ),
        Row(children: [
          StudioButton(
            label: 'Refresh',
            icon: Icons.refresh,
            busy: c.adbBusy,
            onPressed: c.refreshAdb,
          ),
          const SizedBox(width: 8),
          if (c.adbError != null)
            StudioButton(
              label: 'Set adb path',
              icon: Icons.folder_open,
              onPressed: () => AdbPathDialog.show(context),
            ),
        ]),
      ],
    );
  }
}
