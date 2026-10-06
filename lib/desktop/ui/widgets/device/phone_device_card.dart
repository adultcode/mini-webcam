import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';
import '../common/inset_panel.dart';
import '../common/status_badge.dart';
import '../common/studio_button.dart';
import '../common/studio_card.dart';
import 'connect_options.dart';
import 'device_metric.dart';

/// Phone link: details and Disconnect when connected, connect options otherwise.
class PhoneDeviceCard extends StatelessWidget {
  const PhoneDeviceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DesktopProvider>();
    final s = c.status;
    final (label, color) = switch (s.state) {
      'streaming' => ('Connected', StudioColors.success),
      'connecting' => ('Connecting', StudioColors.warning),
      'reconnecting' => ('Reconnecting', StudioColors.warning),
      'error' => ('Error', StudioColors.danger),
      _ => ('Disconnected', StudioColors.textMuted),
    };

    return StudioCard(
      icon: Icons.smartphone,
      title: 'Phone Device',
      trailing: StatusBadge(label: label, color: color),
      children: c.active
          ? [
              InsetPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.device.isNotEmpty ? s.device : (c.target ?? ''),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          s.message.isNotEmpty
                              ? s.message
                              : c.connectedVia == ConnectionMode.usb
                                  ? 'USB (adb port forwarding)'
                                  : 'Wi-Fi · ${c.target ?? ''}',
                          style: StudioText.caption,
                        ),
                      ]),
                    ),
                    _LinkTag(usb: c.connectedVia == ConnectionMode.usb),
                  ]),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Row(children: [
                    Expanded(
                      child: DeviceMetric(
                          icon: Icons.speed, color: StudioColors.success, text: '${s.fps.toStringAsFixed(0)} fps'),
                    ),
                    Expanded(
                      child: DeviceMetric(
                          icon: Icons.timer_outlined,
                          color: StudioColors.accent,
                          text: '${s.decodeMs.toStringAsFixed(1)} ms'),
                    ),
                    Expanded(
                      child: DeviceMetric(
                          icon: Icons.network_check,
                          color: StudioColors.warning,
                          text: '${(s.kbps / 1000).toStringAsFixed(1)} Mb/s'),
                    ),
                  ]),
                ]),
              ),
              StudioButton(
                label: 'Disconnect',
                icon: Icons.link_off,
                style: StudioButtonStyle.danger,
                onPressed: c.disconnect,
              ),
            ]
          : const [ConnectOptions()],
    );
  }
}

class _LinkTag extends StatelessWidget {
  const _LinkTag({required this.usb});

  final bool usb;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF083344),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF155E75)),
      ),
      child: Text(usb ? 'USB' : 'Wi-Fi',
          style: const TextStyle(fontFamily: StudioText.mono, fontSize: 10, color: Color(0xFF67E8F9))),
    );
  }
}
