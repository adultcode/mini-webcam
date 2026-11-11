/// Background effect applied on the PC before the preview and the virtual
/// camera. The index is the value the native receiver expects.
enum BackgroundMode {
  off('Off'),
  blur('Blur'),
  image('Image');

  const BackgroundMode(this.label);

  final String label;

  static BackgroundMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => off);
}
