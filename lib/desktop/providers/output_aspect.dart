/// Shape of the video sent to the preview and the virtual camera.
enum OutputAspect {
  original('Original', 0, 0),
  wide('16:9', 16, 9),
  standard('4:3', 4, 3),
  square('1:1', 1, 1);

  const OutputAspect(this.label, this.width, this.height);

  final String label;
  final int width;
  final int height;

  static OutputAspect fromName(String? name) =>
      values.firstWhere((a) => a.name == name, orElse: () => original);
}
