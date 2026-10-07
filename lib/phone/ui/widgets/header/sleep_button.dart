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
          padding: EdgeInsets.all(10),
          child: Icon(Icons.dark_mode_outlined, size: 18, color: OledColors.cyan),
        ),
      ),
    );
  }
}
