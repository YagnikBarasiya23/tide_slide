import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide_slide/src/zipper_painter.dart';
import 'package:tide_slide/tide_slide.dart';

Widget host(
  Widget child, {
  TextDirection dir = TextDirection.ltr,
  ThemeData? theme,
  bool disableAnimations = false,
  double width = 300,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: disableAnimations),
      child: Directionality(textDirection: dir, child: c!),
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

final thumb = find.descendant(
  of: find.byType(TideSlide),
  matching: find.byType(GestureDetector),
);

// Track 300, thumb 48, insets 4+4 -> travel 244. Thumb centre at rest is 28.
const travel = 244.0;
const restCenter = 28.0;

Future<void> drag(WidgetTester tester, double dx, {int steps = 6}) async {
  final g = await tester.startGesture(tester.getCenter(thumb));
  for (var i = 0; i < steps; i++) {
    await g.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 40));
  }
  await tester.pump(const Duration(milliseconds: 200));
  await g.up();
}

Future<void> settle(WidgetTester tester, [int seconds = 1]) async {
  await tester.pump();
  await tester.pump(Duration(seconds: seconds));
}

ZipperPainter zipper(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<ZipperPainter>()
    .single;

List<ZipperTooth> teethOf(WidgetTester tester) {
  final z = zipper(tester);
  return layoutZipper(
    const Size(300, 56),
    thumbCenter: z.thumbCenter,
    toothSize: z.toothSize,
    toothGap: z.toothGap,
    reduced: z.reduced,
    settle: z.settle,
  );
}

Widget zip({
  VoidCallback? onConfirmed,
  double toothSize = 6,
  double toothGap = 4,
}) => TideSlide.zipper(
  label: 'Slide to seal',
  confirmedLabel: 'Sealed',
  onConfirmed: onConfirmed ?? () {},
  toothSize: toothSize,
  toothGap: toothGap,
);

void main() {
  group('zipperClosedAmount', () {
    test('open ahead of the thumb, closed well behind it', () {
      double k(double x) =>
          zipperClosedAmount(toothX: x, thumbCenter: 100, blend: 40);
      expect(k(150), 0);
      expect(k(100), 0);
      expect(k(80), closeTo(0.5, 1e-9));
      expect(k(60), 1);
      expect(k(0), 1);
    });

    test('reduced motion is a hard cut at the thumb', () {
      double k(double x) => zipperClosedAmount(
        toothX: x,
        thumbCenter: 100,
        blend: 40,
        reduced: true,
      );
      expect(k(101), 0);
      expect(k(99), 1);
    });

    test('settle closes every tooth', () {
      final teeth = layoutZipper(
        const Size(300, 56),
        thumbCenter: restCenter,
        toothSize: 6,
        toothGap: 4,
        settle: 1,
      );
      expect(teeth, isNotEmpty);
      expect(teeth.every((t) => t.closed == 1), isTrue);
    });

    test('closed teeth overlap so the rows interlock', () {
      final t = layoutZipper(
        const Size(300, 56),
        thumbCenter: 400,
        toothSize: 6,
        toothGap: 4,
      ).first;
      expect(t.bottom, lessThan(t.top + 6));
    });
  });

  testWidgets('renders with no configuration via the named constructor', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TideSlide.zipper(label: 'Slide to seal', onConfirmed: () {})),
    );
    final w = tester.widget<TideSlide>(find.byType(TideSlide));
    expect(w.style, TideSlideStyle.zipper);
    expect(w.toothSize, 6);
    expect(w.toothGap, 4);
    expect(find.text('Slide to seal'), findsOneWidget);
    expect(teethOf(tester).every((t) => t.closed == 0), isTrue);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders with no configuration via the style parameter', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TideSlide(
          label: 'Slide to seal',
          onConfirmed: () {},
          style: TideSlideStyle.zipper,
        ),
      ),
    );
    expect(zipper(tester).thumbCenter, restCenter);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default style is still tide with no teeth', (tester) async {
    await tester.pumpWidget(host(TideSlide(label: 'Go', onConfirmed: () {})));
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter);
    expect(painters.whereType<ZipperPainter>(), isEmpty);
  });

  testWidgets('teeth close behind the thumb and stay open ahead (LTR)', (
    tester,
  ) async {
    await tester.pumpWidget(host(zip()));
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 50));
    final z = zipper(tester);
    expect(z.rtl, isFalse);
    expect(z.thumbCenter, closeTo(restCenter + 120, 1));
    final teeth = teethOf(tester);
    for (final t in teeth) {
      if (t.x >= z.thumbCenter) expect(t.closed, 0);
      if (t.x <= z.thumbCenter - 40) expect(t.closed, 1);
    }
    expect(teeth.where((t) => t.closed == 1), isNotEmpty);
    expect(teeth.where((t) => t.closed == 0), isNotEmpty);
    expect(tester.hasRunningAnimations, isFalse);
    await g.up();
    await settle(tester, 2);
  });

  testWidgets('teeth follow the thumb in RTL', (tester) async {
    await tester.pumpWidget(host(zip(), dir: TextDirection.rtl));
    final startX = tester.getCenter(thumb).dx;
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getCenter(thumb).dx, lessThan(startX));
    final z = zipper(tester);
    expect(z.rtl, isTrue);
    expect(z.thumbCenter, closeTo(restCenter + 120, 1));
    expect(teethOf(tester).where((t) => t.closed == 1), isNotEmpty);
    await g.up();
    await settle(tester, 2);
  });

  testWidgets('early release opens the teeth again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(zip(onConfirmed: () => calls++)));
    await drag(tester, travel * 0.5);
    await settle(tester, 2);
    expect(calls, 0);
    expect(zipper(tester).thumbCenter, closeTo(restCenter, 0.5));
    expect(teethOf(tester).every((t) => t.closed == 0), isTrue);
    expect(find.text('Slide to seal'), findsOneWidget);
  });

  testWidgets('confirm closes every tooth and shows the success state', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(host(zip(onConfirmed: () => calls++)));
    await drag(tester, travel);
    await settle(tester, 1);
    expect(calls, 1);
    expect(zipper(tester).settle, 1);
    expect(teethOf(tester).every((t) => t.closed == 1), isTrue);
    expect(find.text('Sealed'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('controller reset reopens the zipper', (tester) async {
    final c = TideSlideController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(TideSlide.zipper(label: 'Go', onConfirmed: () {}, controller: c)),
    );
    unawaited(c.confirm());
    await settle(tester, 1);
    expect(c.isConfirmed, isTrue);
    unawaited(c.reset());
    await settle(tester, 1);
    expect(c.isConfirmed, isFalse);
    expect(teethOf(tester).every((t) => t.closed == 0), isTrue);
  });

  testWidgets('toothSize and toothGap are passed through and respected', (
    tester,
  ) async {
    await tester.pumpWidget(host(zip(toothSize: 8, toothGap: 2)));
    final z = zipper(tester);
    expect(z.toothSize, 8);
    expect(z.toothGap, 2);
    final teeth = teethOf(tester);
    expect(teeth[1].x - teeth[0].x, closeTo(10, 1e-9));
  });

  testWidgets('teeth stay inside the track at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TideSlide.zipper(
              label: 'Slide to seal this very long label for the test',
              onConfirmed: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(TideSlide));
    expect(size.width, 288);
    final teeth = layoutZipper(
      size,
      thumbCenter: 400,
      toothSize: 6,
      toothGap: 4,
    );
    for (final t in teeth) {
      expect(t.x, greaterThanOrEqualTo(size.height / 2));
      expect(t.x + 10 + 6, lessThanOrEqualTo(size.width - size.height / 2 + 6));
      expect(t.top, greaterThanOrEqualTo(0));
      expect(t.bottom + 6, lessThanOrEqualTo(size.height));
    }
  });

  testWidgets('reduced motion: hard cut and a short linear return', (
    tester,
  ) async {
    await tester.pumpWidget(host(zip(), disableAnimations: true));
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(zipper(tester).reduced, isTrue);
    expect(
      teethOf(tester).every((t) => t.closed == 0 || t.closed == 1),
      isTrue,
    );
    expect(tester.hasRunningAnimations, isFalse);
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(zipper(tester).thumbCenter, closeTo(restCenter, 0.5));
  });

  testWidgets('invalid tooth sizes are rejected in debug builds', (
    tester,
  ) async {
    expect(
      () => TideSlide.zipper(label: 'x', onConfirmed: () {}, toothSize: 0),
      throwsAssertionError,
    );
    expect(
      () => TideSlide.zipper(label: 'x', onConfirmed: () {}, toothGap: -1),
      throwsAssertionError,
    );
  });

  testWidgets('switching style at runtime works both ways', (tester) async {
    await tester.pumpWidget(host(TideSlide(label: 'Go', onConfirmed: () {})));
    await tester.pumpWidget(
      host(TideSlide.zipper(label: 'Go', onConfirmed: () {})),
    );
    expect(zipper(tester), isNotNull);
    await tester.pumpWidget(host(TideSlide(label: 'Go', onConfirmed: () {})));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during the zipper animation is safe', (tester) async {
    await tester.pumpWidget(host(zip()));
    await drag(tester, travel * 0.5);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const SizedBox());
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  group('golden', () {
    Future<void> shot(
      WidgetTester tester,
      String name, {
      required Brightness brightness,
      double? dragBy,
      bool confirm = false,
    }) async {
      tester.view.physicalSize = const Size(340, 100);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: host(
            TideSlide.zipper(
              label: 'Slide to seal',
              confirmedLabel: 'Sealed',
              onConfirmed: () {},
            ),
            theme: ThemeData(brightness: brightness, useMaterial3: true),
          ),
        ),
      );
      if (dragBy != null) {
        final g = await tester.startGesture(tester.getCenter(thumb));
        await g.moveBy(Offset(dragBy, 0));
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (confirm) {
        await drag(tester, travel);
        await settle(tester, 1);
      }
      await expectLater(
        find.byKey(const ValueKey('shot')),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    for (final b in Brightness.values) {
      final mode = b == Brightness.light ? 'light' : 'dark';
      testWidgets(
        'zipper idle $mode',
        (t) => shot(t, 'zipper_idle_$mode', brightness: b),
      );
      testWidgets(
        'zipper mid $mode',
        (t) => shot(t, 'zipper_mid_$mode', brightness: b, dragBy: 130),
      );
      testWidgets(
        'zipper confirmed $mode',
        (t) => shot(t, 'zipper_confirmed_$mode', brightness: b, confirm: true),
      );
    }
  });
}
