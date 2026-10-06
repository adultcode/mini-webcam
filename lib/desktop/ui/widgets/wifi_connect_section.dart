import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/desktop_provider.dart';

/// Phones found on the LAN, plus manual IP entry.
class WifiConnectSection extends StatefulWidget {
  const WifiConnectSection({super.key});

  @override
  State<WifiConnectSection> createState() => _WifiConnectSectionState();
}

class _WifiConnectSectionState extends State<WifiConnectSection> {
  final _host = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    // Prefill with the last used IP once saved settings have loaded.
    if (!_seeded && c.lastHost.isNotEmpty) {
      _host.text = c.lastHost;
      _seeded = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.discovered.isEmpty)
          Text('Searching the network... Open Mini Webcam on the phone (same Wi-Fi).',
              style: Theme.of(context).textTheme.bodySmall)
        else
          for (final phone in c.discovered)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smartphone),
              title: Text(phone.name),
              subtitle: Text(phone.address + (phone.streaming ? '  ·  streaming' : '')),
              trailing: FilledButton.tonal(
                onPressed: () {
                  _host.text = phone.address;
                  c.connectWifi(phone.address);
                },
                child: const Text('Connect'),
              ),
            ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _host,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Phone IP',
                hintText: '192.168.1.20',
              ),
              onSubmitted: c.connectWifi,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => c.connectWifi(_host.text),
            child: const Text('Connect'),
          ),
        ]),
      ],
    );
  }
}
