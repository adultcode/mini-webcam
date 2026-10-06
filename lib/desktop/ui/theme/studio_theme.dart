import 'package:flutter/material.dart';

/// Fluent-style dark palette for the desktop studio window.
class StudioColors {
  static const window = Color(0xFF0B0F14);
  static const surface = Color(0xFF131922);
  static const card = Color(0xFF19222E);
  static const border = Color(0xFF2A3546);
  static const divider = Color(0xFF1E293B);
  static const accent = Color(0xFF38BDF8);
  static const accentSoft = Color(0x1F38BDF8);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFF43F5E);
  static const hud = Color(0x99000000);
}

class StudioText {
  static const mono = 'Consolas';

  static const title = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0), letterSpacing: 0.2);
  static const label = TextStyle(fontSize: 12, color: StudioColors.textSecondary);
  static const caption = TextStyle(fontSize: 11, color: StudioColors.textSecondary);
  static const body = TextStyle(fontSize: 12, color: StudioColors.textPrimary);
  static const value = TextStyle(
      fontFamily: mono, fontSize: 12, fontWeight: FontWeight.w600, color: StudioColors.textPrimary);
}

ThemeData buildStudioTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: StudioColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: StudioColors.accent,
    onPrimary: const Color(0xFF020617),
    surface: StudioColors.surface,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: StudioColors.window,
    dividerColor: StudioColors.divider,
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: StudioColors.accent,
      inactiveTrackColor: const Color(0xFF1F2937),
      thumbColor: StudioColors.accent,
      overlayColor: StudioColors.accent.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? StudioColors.accent : const Color(0xFF1E293B)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: StudioColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: StudioColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: StudioColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: StudioColors.accent),
      ),
      labelStyle: StudioText.label,
      hintStyle: const TextStyle(fontSize: 12, color: StudioColors.textMuted),
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
  );
}
