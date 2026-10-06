import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../../providers/studio_view_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/studio_button.dart';
import 'device_list_tile.dart';

/// Phones discovered on the LAN, plus manual IP entry.
class WifiConnectList extends StatelessWidget {
  const WifiConnectList({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final view = context.read<StudioViewProvider>()..seedHost(c.lastHost);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.discovered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Searching the network... Open Mini Webcam on the phone (same Wi-Fi).',
                style: StudioText.caption),
          )
        else
          for (final phone in c.discovered)
            DeviceListTile(
              icon: Icons.smartphone,
              title: phone.name,
              subtitle: phone.address + (phone.streaming ? '  ·  streaming' : ''),
              onConnect: () {
                view.hostController.text = phone.address;
                c.connectWifi(phone.address);
              },
            ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: view.hostController,
              style: StudioText.body,
              decoration: const InputDecoration(hintText: 'Phone IP, e.g. 192.168.1.20'),
              onSubmitted: c.connectWifi,
            ),
          ),
          const SizedBox(width: 8),
          StudioButton(
            label: 'Connect',
            style: StudioButtonStyle.primary,
            onPressed: () => c.connectWifi(view.hostController.text),
          ),
        ]),
      ],
    );
  }
}
