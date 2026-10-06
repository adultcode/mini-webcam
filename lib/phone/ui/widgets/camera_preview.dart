import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/phone_provider.dart';

/// Native camera texture, rotated for the portrait UI, with tap-to-focus and
/// pinch-to-zoom.
class CameraPreview extends StatefulWidget {
  const CameraPreview({super.key});

  @override
  State<CameraPreview> createState() => _CameraPreviewState();
}

class _CameraPreviewState extends State<CameraPreview> {
  double _zoomAtScaleStart = 1;
  Offset? _focusMarker;

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final id = phone.textureId;
    if (id == null) return const Center(child: CircularProgressIndicator());

    final parts = phone.settings.resolution.split('x');
    final w = double.tryParse(parts.first) ?? 16;
    final h = double.tryParse(parts.last) ?? 9;
    final quarterTurns = phone.features.sensorOrientation ~/ 90;

    // Sensor buffers are landscape; in this portrait UI they're shown rotated.
    Widget texture = Texture(textureId: id);
    if (!phone.handlesRotation) {
      texture = RotatedBox(quarterTurns: quarterTurns, child: texture);
      if (phone.features.frontFacing) texture = Transform.flip(flipX: true, child: texture);
    }

    return Center(
      child: AspectRatio(
        aspectRatio: quarterTurns.isOdd ? h / w : w / h,
        child: LayoutBuilder(builder: (context, box) {
          return GestureDetector(
            onTapUp: (d) => _tapToFocus(phone, d.localPosition, box.biggest),
            onScaleStart: (_) => _zoomAtScaleStart = phone.settings.zoom,
            onScaleUpdate: (d) {
              if (d.pointerCount < 2) return;
              final zoom = (_zoomAtScaleStart * d.scale)
                  .clamp(phone.features.zoomMin, phone.features.zoomMax);
              phone.applyChanges({'zoom': zoom});
            },
            child: Stack(fit: StackFit.expand, children: [
              texture,
              if (_focusMarker != null) _FocusMarker(position: _focusMarker!),
            ]),
          );
        }),
      ),
    );
  }

  void _tapToFocus(PhoneProvider phone, Offset p, Size size) {
    var u = p.dx / size.width;
    final v = p.dy / size.height;
    if (phone.features.frontFacing) u = 1 - u;
    // Undo the clockwise sensor rotation to get sensor-space coordinates.
    final (x, y) = switch (phone.features.sensorOrientation) {
      90 => (v, 1 - u),
      180 => (1 - u, 1 - v),
      270 => (1 - v, u),
      _ => (u, v),
    };
    phone.focusAt(x, y);
    setState(() => _focusMarker = p);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusMarker = null);
    });
  }
}

class _FocusMarker extends StatelessWidget {
  const _FocusMarker({required this.position});

  final Offset position;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 32,
      top: position.dy - 32,
      child: IgnorePointer(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amberAccent, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
