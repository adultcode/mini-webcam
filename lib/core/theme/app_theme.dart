import 'package:flutter/material.dart';

const _seed = Color(0xFF3D8BFF);

/// Colours used outside the Material colour scheme.
class AppColors {
  static const background = Color(0xFF0E1116);
  static const surface = Color(0xFF161B22);
  static const outline = Color(0xFF242B35);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
  );
}
