import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Builds the tide shape: a filled region from the start edge to [edge], whose
/// leading edge is a vertical sine wave.
///
/// [phase] is in radians and moves the wave along the edge. When [rtl] is true
/// the shape is mirrored so it fills from the right.
Path buildTidePath(
  Size size, {
  required double edge,
  required double phase,
  required double amplitude,
  required double wavelength,
  bool rtl = false,
}) {
  if (edge <= 0 || size.isEmpty) return Path();
  final path = Path()..moveTo(0, 0);
  final step = 2.0;
  final k = 2 * math.pi / math.max(1.0, wavelength);
  for (var y = 0.0; y <= size.height + step; y += step) {
    final yy = math.min(y, size.height);
    path.lineTo(edge + amplitude * math.sin(k * yy + phase), yy);
  }
  path
    ..lineTo(0, size.height)
    ..close();
  if (!rtl) return path;
  final mirror = Float64List.fromList(<double>[
    -1, 0, 0, 0, //
    0, 1, 0, 0,
    0, 0, 1, 0,
    size.width, 0, 0, 1,
  ]);
  return path.transform(mirror);
}
