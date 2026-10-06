import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/desktop_provider.dart';

/// Last error from a connection, driver or phone action, if any.
class ErrorText extends StatelessWidget {
  const ErrorText({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.select<DesktopProvider, String?>((c) => c.error);
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(error, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
