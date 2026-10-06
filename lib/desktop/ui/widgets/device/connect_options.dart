import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../common/pill_selector.dart';
import 'usb_connect_list.dart';
import 'wifi_connect_list.dart';

/// Wi-Fi / USB switch with the matching connect list.
class ConnectOptions extends StatelessWidget {
  const ConnectOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<DesktopProvider, ConnectionMode>((c) => c.mode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillSelector<ConnectionMode>(
          options: const [
            PillOption(ConnectionMode.wifi, 'Wi-Fi', icon: Icons.wifi),
            PillOption(ConnectionMode.usb, 'USB', icon: Icons.usb),
          ],
          selected: mode,
          onChanged: context.read<DesktopProvider>().setMode,
        ),
        const SizedBox(height: 12),
        if (mode == ConnectionMode.wifi) const WifiConnectList() else const UsbConnectList(),
      ],
    );
  }
}
