import 'dart:ui';

import 'package:flutter/widgets.dart';

/// How closed one tooth is, from 0 (apart) to 1 (meshed).
///
/// A tooth starts closing when the thumb centre reaches it and is fully
/// closed [blend] pixels later, which gives the soft "V" where the rows meet.
/// With [reduced] motion the change is a hard cut at the thumb centre.
double zipperClosedAmount({
  required double toothX,
  required double thumbCenter,
  required double blend,
  bool reduced = false,
}) {
  if (reduced) return thumbCenter > toothX ? 1 : 0;
  if (blend <= 0) return thumbCenter > toothX ? 1 : 0;
  return ((thumbCenter - toothX) / blend).clamp(0.0, 1.0);
}

/// One pair of zipper teeth, in left-to-right track coordinates.
@immutable
class ZipperTooth {
  /// Creates a tooth pair.
  const ZipperTooth({
    required this.x,
    required this.top,
    required this.bottom,
    required this.closed,
  });

  /// Left edge of the top tooth. The bottom tooth sits half a pitch later.
  final double x;

  /// Top edge of the upper tooth.
  final double top;

  /// Top edge of the lower tooth.
  final double bottom;

  /// How closed this pair is, from 0 to 1.
  final double closed;
}

/// Lays out the two rows of teeth for a track of [size].
///
/// [thumbCenter] is the thumb centre measured from the start edge. [settle]
/// goes from 0 to 1 after confirming and closes every tooth.
List<ZipperTooth> layoutZipper(
  Size size, {
  required double thumbCenter,
  required double toothSize,
  required double toothGap,
  bool reduced = false,
  double settle = 0,
}) {
  final h = size.height;
  final pitch = toothSize + toothGap;
  if (size.isEmpty || pitch <= 0) return const [];
  final openTop = h * 0.12;
  final openBottom = h * 0.88 - toothSize;
  final shutTop = h / 2 - toothSize * 0.8;
  final shutBottom = h / 2 - toothSize * 0.2;
  final blend = h * 0.7;
  final teeth = <ZipperTooth>[];
  for (var x = h * 0.5; x + pitch <= size.width - h * 0.5 + 0.01; x += pitch) {
    var k = zipperClosedAmount(
      toothX: x,
      thumbCenter: thumbCenter,
      blend: blend,
      reduced: reduced,
    );
    k = k + (1 - k) * settle;
    teeth.add(
      ZipperTooth(
        x: x,
        top: lerpDouble(openTop, shutTop, k)!,
        bottom: lerpDouble(openBottom, shutBottom, k)!,
        closed: k,
      ),
    );
  }
  return teeth;
}

/// Paints the zipper teeth. Mirrored when [rtl] is true.
class ZipperPainter extends CustomPainter {
  /// Creates a zipper painter.
  const ZipperPainter({
    required this.thumbCenter,
    required this.toothSize,
    required this.toothGap,
    required this.openColor,
    required this.closedColor,
    required this.rtl,
    required this.reduced,
    required this.settle,
  });

  /// Thumb centre from the start edge.
  final double thumbCenter;

  /// Width and height of one tooth.
  final double toothSize;

  /// Space between neighbouring teeth in a row.
  final double toothGap;

  /// Colour of teeth that are apart.
  final Color openColor;

  /// Colour of meshed teeth.
  final Color closedColor;

  /// Whether the track runs right to left.
  final bool rtl;

  /// Whether reduced motion is on.
  final bool reduced;

  /// Confirm progress from 0 to 1.
  final double settle;

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final teeth = layoutZipper(
      size,
      thumbCenter: thumbCenter,
      toothSize: toothSize,
      toothGap: toothGap,
      reduced: reduced,
      settle: settle,
    );
    final half = (toothSize + toothGap) / 2;
    final r = Radius.circular(toothSize * 0.3);
    final paint = Paint();
    for (final t in teeth) {
      paint.color = Color.lerp(openColor, closedColor, t.closed)!;
      canvas
        ..drawRRect(
          RRect.fromLTRBR(t.x, t.top, t.x + toothSize, t.top + toothSize, r),
          paint,
        )
        ..drawRRect(
          RRect.fromLTRBR(
            t.x + half,
            t.bottom,
            t.x + half + toothSize,
            t.bottom + toothSize,
            r,
          ),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(ZipperPainter old) =>
      old.thumbCenter != thumbCenter ||
      old.toothSize != toothSize ||
      old.toothGap != toothGap ||
      old.openColor != openColor ||
      old.closedColor != closedColor ||
      old.rtl != rtl ||
      old.reduced != reduced ||
      old.settle != settle;
}

/// Clips a child to the part of the track ahead of the thumb.
class AheadClipper extends CustomClipper<Rect> {
  /// Creates a clipper. [leading] is the thumb's leading edge from the start.
  const AheadClipper({required this.leading, required this.rtl});

  /// Thumb leading edge, measured from the start edge.
  final double leading;

  /// Whether the track runs right to left.
  final bool rtl;

  @override
  Rect getClip(Size size) => rtl
      ? Rect.fromLTRB(0, 0, size.width - leading, size.height)
      : Rect.fromLTRB(leading, 0, size.width, size.height);

  @override
  bool shouldReclip(AheadClipper old) =>
      old.leading != leading || old.rtl != rtl;
}
