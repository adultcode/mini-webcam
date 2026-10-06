import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';

/// Asks for the location of adb.exe when it can't be found automatically.
class AdbPathDialog extends StatelessWidget {
  const AdbPathDialog({super.key, required this.controller});

  final TextEditingController controller;

  static Future<void> show(BuildContext context) async {
    final desktop = context.read<DesktopProvider>();
    final controller = TextEditingController(text: desktop.adb.customPath ?? '');
    final path = await showDialog<String>(
      context: context,
      builder: (_) => AdbPathDialog(controller: controller),
    );
    controller.dispose();
    if (path != null) await desktop.setAdbPath(path.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.card,
      title: const Text('adb.exe location', style: StudioText.title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: controller,
          style: StudioText.body,
          decoration: const InputDecoration(hintText: r'C:\platform-tools\adb.exe'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
