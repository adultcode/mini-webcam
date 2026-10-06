import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/status_pill.dart';
import '../../providers/desktop_provider.dart';
import 'section_card.dart';
import 'usb_connect_section.dart';
import 'wifi_connect_section.dart';

/// Connection state and the Wi-Fi / USB connect options.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final s = c.status;
    final (label, color) = switch (s.state) {
      'streaming' => ('Live', Colors.greenAccent),
      'connecting' => ('Connecting', Colors.amber),
      'reconnecting' => ('Reconnecting', Colors.orangeAccent),
      'error' => ('Error', Colors.redAccent),
      _ => ('Disconnected', Colors.grey),
    };

    return SectionCard(
      title: 'Phone',
      trailing: StatusPill(label: label, color: color),
      children: c.active
          ? [
              Text(c.target ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (s.message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.message, style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: c.disconnect,
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
              ),
            ]
          : [
              SegmentedButton<ConnectionMode>(
                segments: const [
                  ButtonSegment(
                      value: ConnectionMode.wifi, icon: Icon(Icons.wifi), label: Text('Wi-Fi')),
                  ButtonSegment(
                      value: ConnectionMode.usb, icon: Icon(Icons.usb), label: Text('USB')),
                ],
                selected: {c.mode},
                onSelectionChanged: (v) => c.setMode(v.first),
              ),
              const SizedBox(height: 12),
              if (c.mode == ConnectionMode.wifi)
                const WifiConnectSection()
              else
                const UsbConnectSection(),
            ],
    );
  }
}
