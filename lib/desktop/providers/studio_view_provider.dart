import 'package:flutter/widgets.dart';

/// Pure UI state for the desktop studio window (no device logic):
/// viewport overlays, in-progress slider drags, snapshot progress and the
/// manual IP field. Keeps every widget stateless.
class StudioViewProvider extends ChangeNotifier {
  final hostController = TextEditingController();
  bool _hostSeeded = false;

  bool _showGrid = false;
  bool _snapshotBusy = false;
  final Map<String, double> _drafts = {};

  bool get showGrid => _showGrid;
  bool get snapshotBusy => _snapshotBusy;

  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
  }

  set snapshotBusy(bool value) {
    _snapshotBusy = value;
    notifyListeners();
  }

  /// Prefills the IP field once with the last used address.
  void seedHost(String host) {
    if (_hostSeeded || host.isEmpty) return;
    _hostSeeded = true;
    hostController.text = host;
  }

  /// Value of a slider while it is being dragged, or null when idle.
  double? draft(String id) => _drafts[id];

  void setDraft(String id, double value) {
    _drafts[id] = value;
    notifyListeners();
  }

  void clearDraft(String id) {
    if (_drafts.remove(id) != null) notifyListeners();
  }

  @override
  void dispose() {
    hostController.dispose();
    super.dispose();
  }
}
