import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/blackout_provider.dart';
import '../../../providers/phone_provider.dart';
import '../../theme/oled_theme.dart';

/// OLED battery saver: black screen while streaming, tap anywhere to wake.
class BlackoutOverlay extends StatelessWidget {
  const BlackoutOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    final res = phone.settings.resolution.split('x').last;
    final status = phone.streaming
        ? 'Streaming ${res}p ${phone.settings.fps}fps to ${phone.viewers} '
            '${phone.viewers == 1 ? 'viewer' : 'viewers'}.'
        : 'Not streaming.';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.read<BlackoutProvider>().userActivity,
      child: ColoredBox(
        color: const Color(0xF2000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.power_settings_new, size: 36, color: OledColors.cyan),
              const SizedBox(height: 12),
              const Text('OLED BATTERY SAVER ACTIVE',
                  style: TextStyle(
                      fontFamily: OledText.mono,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: Colors.white)),
              const SizedBox(height: 6),
              SizedBox(
                width: 240,
                child: Text('$status Tap anywhere to wake the preview.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: OledColors.dimText)),
              ),
              if (phone.streaming && phone.viewers > 0) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    '${phone.fps.toStringAsFixed(0)} fps • ${(phone.kbps / 1000).toStringAsFixed(1)} Mb/s',
                    style: const TextStyle(fontFamily: OledText.mono, fontSize: 11, color: OledColors.cyan),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
