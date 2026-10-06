import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/desktop_provider.dart';
import '../../services/adb.dart';

/// adb devices list for USB mode.
class UsbConnectSection extends StatelessWidget {
  const UsbConnectSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enable USB debugging on the phone, plug it in and accept the prompt.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (c.adbError != null) ...[
          Text(c.adbError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _askAdbPath(context, c),
              child: const Text('Set adb.exe path'),
            ),
          ),
        ],
        for (final device in c.adbDevices) _AdbDeviceTile(device: device),
        if (c.adbDevices.isEmpty && c.adbError == null && !c.adbBusy)
          const Text('No devices found.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: c.adbBusy ? null : c.refreshAdb,
            icon: c.adbBusy
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }

  Future<void> _askAdbPath(BuildContext context, DesktopProvider c) async {
    final field = TextEditingController(text: c.adb.customPath ?? '');
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('adb.exe location'),
        content: TextField(
          controller: field,
          decoration: const InputDecoration(hintText: r'C:\platform-tools\adb.exe'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    field.dispose();
    if (path != null) await c.setAdbPath(path.trim());
  }
}

class _AdbDeviceTile extends StatelessWidget {
  const _AdbDeviceTile({required this.device});

  final AdbDevice device;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.usb),
      title: Text(device.model),
      subtitle: Text(
          device.ready ? device.serial : '${device.serial} · ${device.state} (check the phone)'),
      trailing: FilledButton.tonal(
        onPressed: device.ready && !c.adbBusy ? () => c.connectUsb(device) : null,
        child: const Text('Connect'),
      ),
    );
  }
}
