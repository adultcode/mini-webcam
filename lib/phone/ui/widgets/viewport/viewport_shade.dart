import 'package:flutter/material.dart';

/// Dark gradient at the top and bottom so the floating controls stay legible.
class ViewportShade extends StatelessWidget {
  const ViewportShade({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xD9000000), Color(0x00000000), Color(0x00000000), Color(0xF2000000)],
            stops: [0, 0.25, 0.6, 1],
          ),
        ),
      ),
    );
  }
}
