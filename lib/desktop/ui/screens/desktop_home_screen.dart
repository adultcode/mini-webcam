import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/desktop_provider.dart';
import '../widgets/device/phone_device_card.dart';
import '../widgets/device/transform_card.dart';
import '../widgets/device/virtual_driver_card.dart';
import '../widgets/header/studio_header.dart';
import '../widgets/layout/error_banner.dart';
import '../widgets/layout/side_column.dart';
import '../widgets/tuner/encoding_card.dart';
import '../widgets/tuner/lens_card.dart';
import '../widgets/tuner/optics_card.dart';
import '../widgets/tuner/tuner_placeholder.dart';
import '../widgets/viewport/live_viewport.dart';
import '../widgets/viewport/telemetry_bar.dart';

/// Desktop studio: device and output on the left, live viewport in the
/// middle, phone camera tuning on the right.
class DesktopHomeScreen extends StatelessWidget {
  const DesktopHomeScreen({super.key});

  static const _sideWidth = 320.0;
  static const _tunerBreakpoint = 1100.0;

  @override
  Widget build(BuildContext context) {
    final phoneConnected = context.select<DesktopProvider, bool>((c) => c.phone != null);
    final tuner = phoneConnected
        ? const [LensCard(), EncodingCard(), OpticsCard()]
        : const [TunerPlaceholder()];

    return Scaffold(
      body: Column(children: [
        const StudioHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (context, box) {
              final showTuner = box.maxWidth >= _tunerBreakpoint;
              return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: _sideWidth,
                  child: SideColumn(children: [
                    const PhoneDeviceCard(),
                    const VirtualDriverCard(),
                    const TransformCard(),
                    const ErrorBanner(),
                    // Narrow window: tuner moves under the left column.
                    if (!showTuner) ...tuner,
                  ]),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(children: [
                    Expanded(child: LiveViewport()),
                    SizedBox(height: 12),
                    TelemetryBar(),
                  ]),
                ),
                if (showTuner) ...[
                  const SizedBox(width: 12),
                  SizedBox(width: _sideWidth, child: SideColumn(children: tuner)),
                ],
              ]);
            }),
          ),
        ),
      ]),
    );
  }
}
