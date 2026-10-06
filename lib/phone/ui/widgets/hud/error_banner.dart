import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/phone_provider.dart';
import '../../theme/oled_theme.dart';
import '../common/glass_container.dart';

/// Camera or server error, if any.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.select<PhoneProvider, String?>((p) => p.error);
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        radius: 14,
        color: const Color(0xCC2A0A0A),
        borderColor: OledColors.red.withValues(alpha: 0.4),
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: OledColors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFFFECACA)))),
        ]),
      ),
    );
  }
}
