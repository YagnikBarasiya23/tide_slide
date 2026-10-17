import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tide_slide/src/release_logic.dart';
import 'package:tide_slide/src/tide_path.dart';

void main() {
  group('shouldConfirm', () {
    bool go(double progress, double velocity, {double threshold = 0.85}) =>
        shouldConfirm(
          progress: progress,
          velocity: velocity,
          threshold: threshold,
          flingVelocity: 1200,
        );

    test('slow drag needs the threshold', () {
      expect(go(0.84, 0), isFalse);
      expect(go(0.85, 0), isTrue);
      expect(go(1, 0), isTrue);
    });

    test('fast forward fling confirms past halfway', () {
      expect(go(0.6, 2000), isTrue);
      expect(go(0.5, 1200), isTrue);
    });

    test('fast fling before halfway does not confirm', () {
      expect(go(0.3, 5000), isFalse);
    });

    test('backward fling never confirms short of the threshold', () {
      expect(go(0.7, -3000), isFalse);
    });

    test('custom threshold is honoured', () {
      expect(go(0.5, 0, threshold: 0.5), isTrue);
      expect(go(0.49, 0, threshold: 0.5), isFalse);
    });
  });

  group('buildTidePath', () {
    const size = Size(300, 56);

    test('is empty when the edge is at or before the start', () {
      final p = buildTidePath(
        size,
        edge: 0,
        phase: 0,
        amplitude: 4,
        wavelength: 50,
      );
      expect(p.getBounds(), Rect.zero);
    });

    test('fills from the left up to the wavy edge', () {
      final b = buildTidePath(
        size,
        edge: 100,
        phase: 0,
        amplitude: 4,
        wavelength: 50,
      ).getBounds();
      expect(b.left, 0);
      expect(b.top, 0);
      expect(b.bottom, 56);
      expect(b.right, closeTo(104, 0.5));
    });

    test('flat edge when amplitude is zero', () {
      final b = buildTidePath(
        size,
        edge: 120,
        phase: 1,
        amplitude: 0,
        wavelength: 50,
      ).getBounds();
      expect(b.right, closeTo(120, 1e-6));
    });

    test('rtl mirrors the shape to the right side', () {
      final b = buildTidePath(
        size,
        edge: 100,
        phase: 0,
        amplitude: 0,
        wavelength: 50,
        rtl: true,
      ).getBounds();
      expect(b.left, closeTo(200, 1e-6));
      expect(b.right, closeTo(300, 1e-6));
    });

    test('phase shifts the wave but not the bounds by more than amplitude', () {
      for (final phase in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
        final b = buildTidePath(
          size,
          edge: 100,
          phase: phase,
          amplitude: 4,
          wavelength: 50,
        ).getBounds();
        expect(b.right, inInclusiveRange(99.9, 104.1));
      }
    });
  });
}
