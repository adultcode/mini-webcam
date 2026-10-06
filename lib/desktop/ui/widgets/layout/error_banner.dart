import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/desktop_provider.dart';
import '../../theme/studio_theme.dart';

/// Last error from a connection, driver or phone action, if any.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.select<DesktopProvider, String?>((c) => c.error);
    if (error == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudioColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudioColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, size: 16, color: Color(0xFFFB7185)),
        const SizedBox(width: 8),
        Expanded(child: Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFFFECDD3)))),
      ]),
    );
  }
}
