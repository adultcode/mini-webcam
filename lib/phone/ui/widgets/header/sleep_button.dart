import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/blackout_provider.dart';
import '../../theme/oled_theme.dart';
import '../common/glass_container.dart';

/// Blacks the screen out while the stream keeps running.
class SleepButton extends StatelessWidget {
  const SleepButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Dim the display to save battery and heat while streaming',
      child: GestureDetector(
        onTap: context.read<BlackoutProvider>().blackOut,
        child: const GlassContainer(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.dark_mode_outlined, size: 15, color: OledColors.cyan),
            SizedBox(width: 6),
            Text('OLED Sleep', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
