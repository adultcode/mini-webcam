import 'dart:async';

import 'package:flutter/foundation.dart';

/// Blacks out the phone screen while streaming to save battery (OLED) and heat.
///
/// Fed with the streaming state through `ChangeNotifierProxyProvider`, so the
/// timer starts when streaming starts and stops when it ends.
class BlackoutProvider extends ChangeNotifier {
  static const delay = Duration(seconds: 30);

  bool _active = false;
  bool _auto = false;
  bool _streaming = false;
  Timer? _timer;

  bool get active => _active;
  bool get auto => _auto;

  /// Called by the proxy provider whenever the phone state changes.
  void updateStreaming(bool streaming) {
    if (streaming == _streaming) return;
    _streaming = streaming;
    if (!streaming && _active) {
      _active = false;
      notifyListeners();
    }
    _arm();
  }

  void setAuto(bool value) {
    _auto = value;
    _arm();
    notifyListeners();
  }

  /// Turns the screen black right away.
  void blackOut() {
    _timer?.cancel();
    _active = true;
    notifyListeners();
  }

  /// Any touch wakes the screen and restarts the countdown.
  void userActivity() {
    if (_active) {
      _active = false;
      notifyListeners();
    }
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (!_auto || !_streaming) return;
    _timer = Timer(delay, () {
      _active = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
