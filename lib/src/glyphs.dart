import 'package:flutter/widgets.dart';

/// Two forward chevrons, drawn in code. Mirrored when [rtl] is true.
class ChevronsPainter extends CustomPainter {
  /// Creates a chevron painter.
  const ChevronsPainter({required this.color, required this.rtl});

  /// Stroke colour.
  final Color color;

  /// Whether to point toward the left.
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide * 0.36;
    final cx = size.width / 2;
    final cy = size.height / 2;
    if (rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < 2; i++) {
      final x0 = cx - s * 0.55 + i * s * 0.6;
      canvas.drawPath(
        Path()
          ..moveTo(x0, cy - s * 0.5)
          ..lineTo(x0 + s * 0.45, cy)
          ..lineTo(x0, cy + s * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ChevronsPainter old) =>
      old.color != color || old.rtl != rtl;
}

/// A tick that draws itself as [progress] goes from 0 to 1.
class CheckPainter extends CustomPainter {
  /// Creates a tick painter.
  const CheckPainter({required this.color, required this.progress});

  /// Stroke colour.
  final Color color;

  /// Draw progress from 0 to 1.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final box = size.shortestSide * 0.42;
    final left = (size.width - box) / 2;
    final top = (size.height - box) / 2;
    Offset p(double x, double y) => Offset(left + box * x, top + box * y);
    final full = Path()
      ..moveTo(p(0.0, 0.55).dx, p(0.0, 0.55).dy)
      ..lineTo(p(0.36, 0.9).dx, p(0.36, 0.9).dy)
      ..lineTo(p(1.0, 0.1).dx, p(1.0, 0.1).dy);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in full.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CheckPainter old) =>
      old.color != color || old.progress != progress;
}

/// Paints a precomputed [path] with [color].
class FillPathPainter extends CustomPainter {
  /// Creates a path painter.
  const FillPathPainter(this.path, this.color);

  /// Shape to fill.
  final Path path;

  /// Fill colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(FillPathPainter old) => true;
}

/// Clips to a precomputed [path].
class PathClipper extends CustomClipper<Path> {
  /// Creates a clipper.
  const PathClipper(this.path);

  /// Clip shape.
  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(PathClipper old) => true;
}
