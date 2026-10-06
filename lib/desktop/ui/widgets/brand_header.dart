import 'package:flutter/material.dart';

/// Logo and app name at the top of the side panel.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Image.asset('assets/logo.png', height: 36),
      const SizedBox(width: 10),
      Text('Mini Webcam', style: Theme.of(context).textTheme.titleLarge),
    ]);
  }
}
