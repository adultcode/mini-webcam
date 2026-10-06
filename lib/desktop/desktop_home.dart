import 'package:flutter/material.dart';

import '../shared/models.dart';
import '../shared/theme.dart';
import 'adb.dart';
import 'desktop_controller.dart';
import 'virtual_cam_installer.dart';

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key, this.args = const []});

  final List<String> args;

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  final c = DesktopController();
  final _hostField = TextEditingController();

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    c.init().then((_) {
      _hostField.text = c.lastHost;
      c.autoConnect(widget.args);
    });
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    c.dispose();
    _hostField.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > 1180;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 330, child: _leftPanel()),
            Expanded(child: _center()),
            if (wide && c.phone != null) SizedBox(width: 300, child: _phonePanel()),
          ],
        );
      }),
    );
  }

  // --- left panel -----------------------------------------------------------

  Widget _leftPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Image.asset('assets/logo.png', height: 36),
          const SizedBox(width: 10),
          Text('Mini Webcam', style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 16),
        _connectionCard(),
        const SizedBox(height: 12),
        _virtualCamCard(),
        const SizedBox(height: 12),
        _outputCard(),
        if (c.error != null) ...[
          const SizedBox(height: 12),
          Text(c.error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }

  Widget _card(String title, List<Widget> children, {Widget? trailing}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              ?trailing,
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _connectionCard() {
    final s = c.status;
    final (label, color) = switch (s.state) {
      'streaming' => ('Live', Colors.greenAccent),
      'connecting' => ('Connecting', Colors.amber),
      'reconnecting' => ('Reconnecting', Colors.orangeAccent),
      'error' => ('Error', Colors.redAccent),
      _ => ('Disconnected', Colors.grey),
    };

    return _card(
      'Phone',
      trailing: StatusPill(label: label, color: color),
      [
        if (c.active) ...[
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
        ] else ...[
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
          if (c.mode == ConnectionMode.wifi) ..._wifiSection() else ..._usbSection(),
        ],
      ],
    );
  }

  List<Widget> _wifiSection() => [
        if (c.discovered.isEmpty)
          Text('Searching the network... Open Mini Webcam on the phone (same Wi-Fi).',
              style: Theme.of(context).textTheme.bodySmall)
        else
          for (final p in c.discovered)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smartphone),
              title: Text(p.name),
              subtitle: Text(p.address + (p.streaming ? '  ·  streaming' : '')),
              trailing: FilledButton.tonal(
                onPressed: () {
                  _hostField.text = p.address;
                  c.connectWifi(p.address);
                },
                child: const Text('Connect'),
              ),
            ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _hostField,
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
            onPressed: () => c.connectWifi(_hostField.text),
            child: const Text('Connect'),
          ),
        ]),
      ];

  List<Widget> _usbSection() => [
        Text('Enable USB debugging on the phone, plug it in and accept the prompt.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (c.adbError != null) ...[
          Text(c.adbError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          TextButton(onPressed: _askAdbPath, child: const Text('Set adb.exe path')),
        ],
        for (final d in c.adbDevices) _adbTile(d),
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
      ];

  Widget _adbTile(AdbDevice d) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.usb),
        title: Text(d.model),
        subtitle: Text(d.ready ? d.serial : '${d.serial} · ${d.state} (check the phone)'),
        trailing: FilledButton.tonal(
          onPressed: d.ready && !c.adbBusy ? () => c.connectUsb(d) : null,
          child: const Text('Connect'),
        ),
      );

  Future<void> _askAdbPath() async {
    final field = TextEditingController(text: c.adb.customPath ?? '');
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('adb.exe location'),
        content: TextField(
          controller: field,
          decoration: const InputDecoration(
              hintText: r'C:\platform-tools\adb.exe'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, field.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (path != null) await c.setAdbPath(path.trim());
  }

  Widget _virtualCamCard() {
    final s = c.status;
    final String detail;
    if (!c.driverInstalled) {
      detail = 'Install the driver once so other apps can see "${VirtualCamInstaller.deviceName}".';
    } else if (s.vcamError.isNotEmpty) {
      detail = s.vcamError;
    } else if (s.vcamAppConnected) {
      detail = 'In use by an app.';
    } else if (s.vcamActive) {
      detail = 'Ready. Pick "${VirtualCamInstaller.deviceName}" in Zoom, Teams, OBS...';
    } else {
      detail = c.vcamEnabled ? 'Waiting for video.' : 'Off.';
    }

    return _card(
      'Virtual webcam',
      trailing: Switch(
        value: c.vcamEnabled && c.driverInstalled,
        onChanged: c.driverInstalled ? c.setVirtualCamera : null,
      ),
      [
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Row(children: [
          if (!c.driverInstalled)
            FilledButton.icon(
              onPressed: c.driverBusy ? null : () => c.installDriver(),
              icon: const Icon(Icons.download),
              label: const Text('Install driver'),
            )
          else
            TextButton(
              onPressed: c.driverBusy ? null : () => c.installDriver(uninstall: true),
              child: const Text('Uninstall driver'),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Re-check',
            onPressed: c.refreshSystemCameras,
            icon: const Icon(Icons.refresh),
          ),
        ]),
      ],
    );
  }

  Widget _outputCard() {
    return _card('Output', [
      const Text('Rotation', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 0, label: Text('0°')),
          ButtonSegment(value: 90, label: Text('90°')),
          ButtonSegment(value: 180, label: Text('180°')),
          ButtonSegment(value: 270, label: Text('270°')),
        ],
        selected: {c.rotation},
        onSelectionChanged: (v) => c.setTransform(rotation: v.first),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Mirror'),
        value: c.mirror,
        onChanged: (v) => c.setTransform(mirror: v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Show preview'),
        subtitle: const Text('Turn off to save CPU'),
        value: c.preview,
        onChanged: c.setPreview,
      ),
    ]);
  }

  // --- center ---------------------------------------------------------------

  Widget _center() {
    final s = c.status;
    final aspect = s.width > 0 && s.height > 0 ? s.width / s.height : 16 / 9;
    final narrow = MediaQuery.sizeOf(context).width <= 1180;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF242B35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(
              child: c.textureId != null && s.isStreaming && c.preview
                  ? AspectRatio(aspectRatio: aspect, child: Texture(textureId: c.textureId!))
                  : _placeholder(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _statsBar(),
        if (narrow && c.phone != null) ...[
          const SizedBox(height: 10),
          SizedBox(height: 230, child: _phonePanel(horizontal: true)),
        ],
      ]),
    );
  }

  Widget _placeholder() {
    final s = c.status;
    final text = switch (s.state) {
      'streaming' => 'Preview hidden',
      'connecting' || 'reconnecting' => s.message,
      _ => 'Connect to your phone to start',
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(s.isIdle ? Icons.phone_android : Icons.hourglass_top,
          size: 48, color: Colors.white24),
      const SizedBox(height: 12),
      Text(text, style: const TextStyle(color: Colors.white54)),
    ]);
  }

  Widget _statsBar() {
    final s = c.status;
    Widget stat(String label, String value) => Padding(
          padding: const EdgeInsets.only(right: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            stat('Device', s.device.isEmpty ? '—' : s.device),
            stat('Codec', s.codec.isEmpty ? '—' : s.codec.toUpperCase()),
            stat('Resolution', s.width > 0 ? '${s.width}×${s.height}' : '—'),
            stat('FPS', s.fps.toStringAsFixed(1)),
            stat('Bitrate', '${(s.kbps / 1000).toStringAsFixed(2)} Mbps'),
            stat('Decode', '${s.decodeMs.toStringAsFixed(1)} ms'),
            if (s.decodeErrors > 0) stat('Decode errors', '${s.decodeErrors}'),
          ]),
        ),
      ),
    );
  }

  // --- phone remote controls ------------------------------------------------

  Widget _phonePanel({bool horizontal = false}) {
    final p = c.phone!;
    final st = p.settings;
    final f = p.features;
    final resolutions =
        f.resolutions.contains(st.resolution) ? f.resolutions : [...f.resolutions, st.resolution];

    final controls = <Widget>[
      Row(children: [
        if (f.cameras.length > 1)
          IconButton.filledTonal(
            tooltip: 'Switch camera',
            onPressed: () =>
                c.updatePhone({'camera': st.camera == 'back' ? 'front' : 'back'}),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        const SizedBox(width: 8),
        if (f.hasFlash)
          IconButton.filledTonal(
            tooltip: 'Torch',
            isSelected: st.torch,
            onPressed: () => c.updatePhone({'torch': !st.torch}),
            icon: Icon(st.torch ? Icons.flashlight_on : Icons.flashlight_off_outlined),
          ),
        const SizedBox(width: 8),
        Text(st.camera == 'back' ? 'Back camera' : 'Front camera'),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('res-${st.resolution}'),
        initialValue: st.resolution,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Resolution', isDense: true),
        items: [
          for (final r in resolutions) DropdownMenuItem(value: r, child: Text(resolutionLabel(r))),
        ],
        onChanged: (v) => c.updatePhone({'resolution': v}),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            key: ValueKey('fps-${st.fps}'),
            initialValue: f.fps.contains(st.fps) ? st.fps : null,
            isDense: true,
            decoration: const InputDecoration(labelText: 'FPS', isDense: true),
            items: [for (final v in f.fps) DropdownMenuItem(value: v, child: Text('$v'))],
            onChanged: (v) => c.updatePhone({'fps': v}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('codec-${st.codec}'),
            initialValue: st.codec,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Codec', isDense: true),
            items: const [
              DropdownMenuItem(value: 'h264', child: Text('H.264')),
              DropdownMenuItem(value: 'mjpeg', child: Text('MJPEG')),
            ],
            onChanged: (v) => c.updatePhone({'codec': v}),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (st.codec == 'h264')
        DropdownButtonFormField<int>(
          key: ValueKey('br-${st.bitrate}'),
          initialValue: bitrateOptions.contains(st.bitrate) ? st.bitrate : null,
          isDense: true,
          decoration: const InputDecoration(labelText: 'Bitrate', isDense: true),
          items: [
            for (final b in bitrateOptions)
              DropdownMenuItem(value: b, child: Text(formatBitrate(b))),
          ],
          onChanged: (v) => c.updatePhone({'bitrate': v}),
        ),
      if (f.zoomMax > f.zoomMin) ...[
        const SizedBox(height: 8),
        Text('Zoom ${st.zoom.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12)),
        _LiveSlider(
          value: st.zoom.clamp(f.zoomMin, f.zoomMax),
          min: f.zoomMin,
          max: f.zoomMax,
          onChanged: (v) => c.updatePhone({'zoom': v}),
        ),
      ],
      if (f.exposureMax > f.exposureMin) ...[
        Text('Exposure ${(st.exposure * f.exposureStep).toStringAsFixed(1)} EV',
            style: const TextStyle(fontSize: 12)),
        _LiveSlider(
          value: st.exposure.toDouble().clamp(f.exposureMin.toDouble(), f.exposureMax.toDouble()),
          min: f.exposureMin.toDouble(),
          max: f.exposureMax.toDouble(),
          divisions: f.exposureMax - f.exposureMin,
          onChanged: (v) => c.updatePhone({'exposure': v.round()}),
        ),
      ],
      if (f.manualFocus) ...[
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Manual focus'),
          value: st.focusMode == 'manual',
          onChanged: (v) => c.updatePhone({'focusMode': v ? 'manual' : 'auto'}),
        ),
        if (st.focusMode == 'manual')
          _LiveSlider(
            value: st.focusDistance,
            min: 0,
            max: 1,
            onChanged: (v) => c.updatePhone({'focusDistance': v}),
          ),
      ],
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(0, horizontal ? 0 : 16, horizontal ? 0 : 16, horizontal ? 0 : 16),
      child: Card(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text('Phone camera', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            ...controls,
          ],
        ),
      ),
    );
  }
}

/// Slider that only sends the value to the phone when the drag ends,
/// so dragging doesn't flood the phone with HTTP requests.
class _LiveSlider extends StatefulWidget {
  const _LiveSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  State<_LiveSlider> createState() => _LiveSliderState();
}

class _LiveSliderState extends State<_LiveSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: (_dragging ?? widget.value).clamp(widget.min, widget.max),
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      onChanged: (v) => setState(() => _dragging = v),
      onChangeEnd: (v) {
        widget.onChanged(v);
        setState(() => _dragging = null);
      },
    );
  }
}
