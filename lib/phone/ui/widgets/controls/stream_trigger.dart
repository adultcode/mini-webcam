import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../../theme/oled_theme.dart';

/// Main start/stop button: glowing cyan while streaming, muted when off.
class StreamTrigger extends StatelessWidget {
  const StreamTrigger({super.key});

  @override
  Widget build(BuildContext context) {
    final streaming = context.select<PhoneProvider, bool>((p) => p.streaming);
    return Tooltip(
      message: streaming ? 'Stop streaming' : 'Start streaming',
      child: GestureDetector(
        onTap: () => context.read<PhoneProvider>().setStreaming(!streaming),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: streaming
                ? const LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [OledColors.cyanDeep, OledColors.cyanMid, OledColors.cyan],
                  )
                : null,
            color: streaming ? null : const Color(0xFF1E293B),
            border: Border.all(color: Colors.black.withValues(alpha: 0.8), width: 4),
            boxShadow: [
              if (streaming) BoxShadow(color: OledColors.cyan.withValues(alpha: 0.65), blurRadius: 24),
              BoxShadow(color: OledColors.cyan.withValues(alpha: 0.4), spreadRadius: 6),
            ],
          ),
          child: Icon(
            streaming ? Icons.videocam : Icons.videocam_off_outlined,
            size: 28,
            color: streaming ? OledColors.onCyan : Colors.white70,
          ),
        ),
      ),
    );
  }
}
