import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../../../providers/phone_view_provider.dart';
import '../../theme/oled_theme.dart';
import 'focus_reticle.dart';

/// Full-screen native camera texture with tap-to-focus and pinch-to-zoom.
class CameraViewport extends StatelessWidget {
  const CameraViewport({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final id = phone.textureId;
    if (id == null) {
      return const Center(child: CircularProgressIndicator(color: OledColors.cyan));
    }

    final parts = phone.settings.resolution.split('x');
    final w = double.tryParse(parts.first) ?? 16;
    final h = double.tryParse(parts.last) ?? 9;
    final quarterTurns = phone.features.sensorOrientation ~/ 90;
    final previewSize = quarterTurns.isOdd ? Size(h, w) : Size(w, h);

    // Sensor buffers are landscape; this portrait UI shows them rotated.
    Widget texture = Texture(textureId: id);
    if (!phone.handlesRotation) {
      texture = RotatedBox(quarterTurns: quarterTurns, child: texture);
      if (phone.features.frontFacing) texture = Transform.flip(flipX: true, child: texture);
    }

    // Cover the screen like a camera app (crop, no bars).
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox.fromSize(
          size: previewSize,
          child: _Gestures(previewSize: previewSize, child: texture),
        ),
      ),
    );
  }
}

class _Gestures extends StatelessWidget {
  const _Gestures({required this.previewSize, required this.child});

  final Size previewSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final phone = context.read<PhoneProvider>();
    final view = context.read<PhoneViewProvider>();
    final focus = context.select<PhoneViewProvider, Offset?>((v) => v.focusPoint);
    final reticleScale = previewSize.shortestSide / 360;

    return GestureDetector(
      onTapUp: (d) {
        view.showFocus(d.localPosition);
        _focusAt(phone, d.localPosition);
      },
      onScaleStart: (_) => view.zoomAtPinchStart = phone.settings.zoom,
      onScaleUpdate: (d) {
        if (d.pointerCount < 2) return;
        final f = phone.features;
        phone.applyChanges({'zoom': (view.zoomAtPinchStart * d.scale).clamp(f.zoomMin, f.zoomMax)});
      },
      child: Stack(fit: StackFit.expand, children: [
        child,
        if (focus != null) FocusReticle(center: focus, scale: reticleScale),
      ]),
    );
  }

  void _focusAt(PhoneProvider phone, Offset p) {
    var u = p.dx / previewSize.width;
    final v = p.dy / previewSize.height;
    if (phone.features.frontFacing) u = 1 - u;
    // Undo the clockwise sensor rotation to get sensor-space coordinates.
    final (x, y) = switch (phone.features.sensorOrientation) {
      90 => (v, 1 - u),
      180 => (1 - u, 1 - v),
      270 => (1 - v, u),
      _ => (u, v),
    };
    phone.focusAt(x, y);
  }
}
