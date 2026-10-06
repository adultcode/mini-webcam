import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../../providers/studio_view_provider.dart';
import '../common/studio_button.dart';

/// Saves the current frame as a PNG in Pictures\Mini Webcam.
class SnapshotButton extends StatelessWidget {
  const SnapshotButton({super.key});

  @override
  Widget build(BuildContext context) {
    final busy = context.select<StudioViewProvider, bool>((v) => v.snapshotBusy);
    return StudioButton(
      label: 'Snapshot (PNG)',
      icon: Icons.photo_camera_outlined,
      style: StudioButtonStyle.primary,
      busy: busy,
      onPressed: () => _capture(context),
    );
  }

  Future<void> _capture(BuildContext context) async {
    final view = context.read<StudioViewProvider>();
    final desktop = context.read<DesktopProvider>();
    final messenger = ScaffoldMessenger.of(context);
    view.snapshotBusy = true;
    try {
      final path = await desktop.takeSnapshot();
      messenger.showSnackBar(SnackBar(
        content: Text('Saved $path'),
        action: SnackBarAction(
          label: 'Show',
          onPressed: () => Process.run('explorer.exe', ['/select,', path]),
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Snapshot failed: $e')));
    } finally {
      view.snapshotBusy = false;
    }
  }
}
