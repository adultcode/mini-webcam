import 'dart:async';

import 'package:flutter/widgets.dart';

/// Pure UI state for the phone screen: the tap-to-focus marker and pinch-zoom
/// bookkeeping. Keeps every phone widget stateless.
class PhoneViewProvider extends ChangeNotifier {
  Offset? _focusPoint;
  Timer? _focusTimer;

  /// Zoom level when the current pinch gesture started (not listened to).
  double zoomAtPinchStart = 1;

  /// Where the focus reticle is drawn, in viewport coordinates.
  Offset? get focusPoint => _focusPoint;

  void showFocus(Offset point) {
    _focusPoint = point;
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1500), () {
      _focusPoint = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    super.dispose();
  }
}
