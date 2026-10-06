import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/phone_provider.dart';

/// Large start/stop streaming button.
class StreamButton extends StatelessWidget {
  const StreamButton({super.key});

  @override
  Widget build(BuildContext context) {
    final streaming = context.select<PhoneProvider, bool>((p) => p.streaming);
    return Tooltip(
      message: streaming ? 'Stop streaming' : 'Start streaming',
      child: GestureDetector(
        onTap: () => context.read<PhoneProvider>().setStreaming(!streaming),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: streaming ? Colors.redAccent : Theme.of(context).colorScheme.primary,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Icon(streaming ? Icons.stop_rounded : Icons.videocam_rounded,
              size: 34, color: Colors.white),
        ),
      ),
    );
  }
}
