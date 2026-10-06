import 'package:flutter/material.dart';

/// Pure-black OLED palette for the phone app.
class OledColors {
  static const black = Color(0xFF000000);
  static const cyan = Color(0xFF60CDFF);
  static const cyanDeep = Color(0xFF0284C7);
  static const cyanMid = Color(0xFF38BDF8);
  static const onCyan = Color(0xFF041D2D);
  static const glass = Color(0xC2080C10);
  static const glassPill = Color(0xA60F141A);
  static const border = Color(0x17FFFFFF);
  static const emerald = Color(0xFF10B981);
  static const emeraldLight = Color(0xFF34D399);
  static const amber = Color(0xFFFCD34D);
  static const red = Color(0xFFF87171);
  static const dimText = Color(0xFF889299);
  static const sheet = Color(0xFF0A0E14);
}

class OledText {
  static const mono = 'monospace';

  static const chip = TextStyle(fontFamily: mono, fontSize: 10, color: Color(0xCCFFFFFF));
  static const small = TextStyle(fontSize: 11, color: Color(0xB3FFFFFF));
  static const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white);
}

ThemeData buildOledTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: OledColors.cyan, brightness: Brightness.dark)
      .copyWith(primary: OledColors.cyan, onPrimary: OledColors.onCyan, surface: OledColors.sheet);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: OledColors.black,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: OledColors.sheet,
      dragHandleColor: Color(0x40FFFFFF),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: OledColors.cyan,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
      thumbColor: OledColors.cyan,
      overlayColor: OledColors.cyan.withValues(alpha: 0.15),
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? OledColors.cyan : Colors.white.withValues(alpha: 0.12)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: OledColors.cyan.withValues(alpha: 0.2),
        selectedForegroundColor: OledColors.cyan,
        side: const BorderSide(color: OledColors.border),
      ),
    ),
  );
}
