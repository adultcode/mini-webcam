import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/blackout_provider.dart';
import '../../providers/phone_provider.dart';

/// Full-screen black layer that keeps streaming while the display looks off.
class BlackoutOverlay extends StatelessWidget {
  const BlackoutOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<PhoneProvider>();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.read<BlackoutProvider>().userActivity,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Text(
          phone.streaming
              ? 'Streaming · ${phone.viewers} connected\nTap to wake'
              : 'Tap to wake',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white24),
        ),
      ),
    );
  }
}
