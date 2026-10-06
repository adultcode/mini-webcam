import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/models.dart';
import '../shared/protocol.dart';
import '../shared/theme.dart';
import 'phone_controller.dart';

class PhoneHome extends StatefulWidget {
  const PhoneHome({super.key});

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> with WidgetsBindingObserver {
  final c = PhoneController();
  bool blackout = false;
  bool autoBlackout = true;
  Timer? _blackoutTimer;
  double _zoomAtScaleStart = 1;
  Offset? _focusMarker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_onChange);
    c.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blackoutTimer?.cancel();
    c.removeListener(_onChange);
    c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.onResume();
  }

  void _onChange() => setState(() {});

  /// Blacks out the screen while streaming to save power (OLED) and heat.
  void _armBlackout() {
    _blackoutTimer?.cancel();
    if (!autoBlackout || !c.streaming) return;
    _blackoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && c.streaming) setState(() => blackout = true);
    });
  }

  void _userActivity() {
    if (blackout) setState(() => blackout = false);
    _armBlackout();
  }

  @override
  Widget build(BuildContext context) {
    if (c.permissionDenied) return _permissionScreen();
    return Listener(
      onPointerDown: (_) => _userActivity(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _preview(),
            _topBar(),
            Align(alignment: Alignment.bottomCenter, child: _bottomBar()),
            if (blackout) _blackoutOverlay(),
          ],
        ),
      ),
    );
  }

  // --- preview --------------------------------------------------------------

  Widget _preview() {
    final id = c.textureId;
    if (id == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final parts = c.settings.resolution.split('x');
    final w = double.tryParse(parts.first) ?? 16;
    final h = double.tryParse(parts.last) ?? 9;
    final quarterTurns = c.features.sensorOrientation ~/ 90;
    final front = c.features.frontFacing;

    // Sensor buffers are landscape; in this portrait UI they're shown rotated.
    Widget texture = Texture(textureId: id);
    if (!c.handlesRotation) {
      texture = RotatedBox(quarterTurns: quarterTurns, child: texture);
      if (front) {
        texture = Transform.flip(flipX: true, child: texture);
      }
    }
    final aspect = quarterTurns.isOdd ? h / w : w / h;

    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(builder: (context, box) {
          return GestureDetector(
            onTapUp: (d) => _tapToFocus(d.localPosition, box.biggest),
            onScaleStart: (_) => _zoomAtScaleStart = c.settings.zoom,
            onScaleUpdate: (d) {
              if (d.pointerCount < 2) return;
              final z = (_zoomAtScaleStart * d.scale)
                  .clamp(c.features.zoomMin, c.features.zoomMax);
              c.applyChanges({'zoom': z});
            },
            child: Stack(fit: StackFit.expand, children: [
              texture,
              if (_focusMarker != null)
                Positioned(
                  left: _focusMarker!.dx - 32,
                  top: _focusMarker!.dy - 32,
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
                ),
            ]),
          );
        }),
      ),
    );
  }

  void _tapToFocus(Offset p, Size size) {
    var u = p.dx / size.width;
    final v = p.dy / size.height;
    if (c.features.frontFacing) u = 1 - u;
    // Undo the clockwise sensor rotation to get sensor-space coordinates.
    final (x, y) = switch (c.features.sensorOrientation) {
      90 => (v, 1 - u),
      180 => (1 - u, 1 - v),
      270 => (1 - v, u),
      _ => (u, v),
    };
    c.focusAt(x, y);
    setState(() => _focusMarker = p);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusMarker = null);
    });
  }

  // --- overlays -------------------------------------------------------------

  Widget _topBar() {
    final clients = c.fcamClients + c.mjpegClients;
    final (label, color) = switch ((c.streaming, clients)) {
      (false, _) => ('Not streaming', Colors.grey),
      (true, 0) => ('Waiting for PC', Colors.amber),
      _ => ('Live · $clients ${clients == 1 ? 'viewer' : 'viewers'}', Colors.greenAccent),
    };
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                StatusPill(label: label, color: color),
                const Spacer(),
                if (c.streaming && clients > 0)
                  Text(
                    '${c.fps.toStringAsFixed(0)} fps · ${(c.kbps / 1000).toStringAsFixed(1)} Mbps',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ]),
              const SizedBox(height: 8),
              Text(
                c.addresses.isEmpty
                    ? 'No network · use USB mode on the PC'
                    : 'Wi-Fi: ${c.addresses.join(', ')}  ·  USB: plug in + enable USB debugging',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              if (c.error != null) ...[
                const SizedBox(height: 6),
                Text(c.error!,
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final f = c.features;
    final s = c.settings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (f.zoomMax > f.zoomMin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(children: [
                  const Icon(Icons.zoom_in, size: 18, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      value: s.zoom.clamp(f.zoomMin, f.zoomMax),
                      min: f.zoomMin,
                      max: f.zoomMax,
                      label: '${s.zoom.toStringAsFixed(1)}x',
                      onChanged: (v) => c.applyChanges({'zoom': v}),
                    ),
                  ),
                  Text('${s.zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(fontSize: 12)),
                ]),
              ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _roundButton(
                  icon: Icons.cameraswitch_outlined,
                  tooltip: 'Switch camera',
                  onTap: f.cameras.length > 1
                      ? () => c.applyChanges(
                          {'camera': s.camera == 'back' ? 'front' : 'back'})
                      : null,
                ),
                _roundButton(
                  icon: s.torch ? Icons.flashlight_on : Icons.flashlight_off_outlined,
                  tooltip: 'Torch',
                  active: s.torch,
                  onTap: f.hasFlash ? () => c.applyChanges({'torch': !s.torch}) : null,
                ),
                _streamButton(),
                _roundButton(
                  icon: Icons.dark_mode_outlined,
                  tooltip: 'Screen off (keeps streaming)',
                  onTap: () => setState(() => blackout = true),
                ),
                _roundButton(
                  icon: Icons.tune,
                  tooltip: 'Settings',
                  onTap: _openSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _streamButton() {
    final on = c.streaming;
    return GestureDetector(
      onTap: () async {
        await c.setStreaming(!on);
        _armBlackout();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? Colors.redAccent : Theme.of(context).colorScheme.primary,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Icon(on ? Icons.stop_rounded : Icons.videocam_rounded,
            size: 34, color: Colors.white),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? Colors.amber.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon,
                color: onTap == null ? Colors.white24 : Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _blackoutOverlay() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _userActivity,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Text(
          c.streaming
              ? 'Streaming · ${c.fcamClients + c.mjpegClients} connected\nTap to wake'
              : 'Tap to wake',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white24),
        ),
      ),
    );
  }

  Widget _permissionScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined, size: 56),
            const SizedBox(height: 16),
            const Text('Camera permission is required to use the phone as a webcam.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: c.retryPermission, child: const Text('Grant permission')),
          ]),
        ),
      ),
    );
  }

  // --- settings sheet -------------------------------------------------------

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          builder: (context, scroll) => _settingsList(scroll),
        ),
      ),
    );
  }

  Widget _settingsList(ScrollController scroll) {
    final s = c.settings;
    final f = c.features;
    final resolutions =
        f.resolutions.contains(s.resolution) ? f.resolutions : [...f.resolutions, s.resolution];
    final fpsOptions = f.fps.contains(s.fps) ? f.fps : [...f.fps, s.fps]..sort();

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('Stream', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('res-${s.resolution}'),
          initialValue: s.resolution,
          decoration: const InputDecoration(labelText: 'Resolution'),
          items: [
            for (final r in resolutions)
              DropdownMenuItem(value: r, child: Text(resolutionLabel(r))),
          ],
          onChanged: (v) => c.applyChanges({'resolution': v}),
        ),
        const SizedBox(height: 16),
        const Text('Frame rate'),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: [
            for (final v in fpsOptions) ButtonSegment(value: v, label: Text('$v')),
          ],
          selected: {s.fps},
          onSelectionChanged: (v) => c.applyChanges({'fps': v.first}),
        ),
        const SizedBox(height: 16),
        const Text('Codec'),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'h264',
                label: Text('H.264'),
                icon: Icon(Icons.bolt_outlined)),
            ButtonSegment(
                value: 'mjpeg',
                label: Text('MJPEG'),
                icon: Icon(Icons.public)),
          ],
          selected: {s.codec},
          onSelectionChanged: (v) => c.applyChanges({'codec': v.first}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            s.codec == 'h264'
                ? 'Hardware encoder. Lowest bandwidth and latency. Recommended for the PC app.'
                : 'Works in any browser/OBS at http://<phone-ip>:${FcamPorts.mjpegPort}/video. Uses more bandwidth and CPU.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        if (s.codec == 'h264')
          DropdownButtonFormField<int>(
            key: ValueKey('br-${s.bitrate}'),
            initialValue: bitrateOptions.contains(s.bitrate) ? s.bitrate : null,
            decoration: const InputDecoration(labelText: 'Bitrate'),
            items: [
              for (final b in bitrateOptions)
                DropdownMenuItem(value: b, child: Text(formatBitrate(b))),
            ],
            onChanged: (v) => c.applyChanges({'bitrate': v}),
          )
        else ...[
          Text('JPEG quality: ${s.jpegQuality}'),
          Slider(
            value: s.jpegQuality.toDouble(),
            min: 30,
            max: 95,
            divisions: 13,
            label: '${s.jpegQuality}',
            onChanged: (v) => c.applyChanges({'jpegQuality': v.round()}),
          ),
        ],
        const Divider(height: 32),
        Text('Image', style: Theme.of(context).textTheme.titleMedium),
        if (f.manualFocus) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Manual focus'),
            subtitle: const Text('Tap the preview for one-shot autofocus'),
            value: s.focusMode == 'manual',
            onChanged: (v) => c.applyChanges({'focusMode': v ? 'manual' : 'auto'}),
          ),
          if (s.focusMode == 'manual')
            Row(children: [
              const Icon(Icons.landscape_outlined, size: 18),
              Expanded(
                child: Slider(
                  value: s.focusDistance,
                  onChanged: (v) => c.applyChanges({'focusDistance': v}),
                ),
              ),
              const Icon(Icons.local_florist_outlined, size: 18),
            ]),
        ],
        if (f.exposureMax > f.exposureMin) ...[
          const SizedBox(height: 8),
          Text('Exposure: ${(s.exposure * f.exposureStep).toStringAsFixed(1)} EV'),
          Slider(
            value: s.exposure.toDouble().clamp(f.exposureMin.toDouble(), f.exposureMax.toDouble()),
            min: f.exposureMin.toDouble(),
            max: f.exposureMax.toDouble(),
            divisions: f.exposureMax - f.exposureMin,
            onChanged: (v) => c.applyChanges({'exposure': v.round()}),
          ),
        ],
        const Divider(height: 32),
        StatefulBuilder(
          builder: (context, setLocal) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto screen-off while streaming'),
            subtitle: const Text('Blacks the screen after 30 s to save battery'),
            value: autoBlackout,
            onChanged: (v) {
              setState(() => autoBlackout = v);
              setLocal(() {});
              _armBlackout();
            },
          ),
        ),
      ],
    );
  }
}
