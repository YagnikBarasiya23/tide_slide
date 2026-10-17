import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

// Track 300, thumb 48, insets 4+4 -> travel 244.
const travel = 244.0;

Future<void> drag(WidgetTester tester, double dx, {int steps = 6}) async {
  final g = await tester.startGesture(tester.getCenter(thumb));
  for (var i = 0; i < steps; i++) {
    await g.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 40));
  }
  await tester.pump(const Duration(milliseconds: 200));
  await g.up();
}

/// A zero-length pump starts any ticker created since the last frame, then
/// time advances in a second pump.
Future<void> settle(WidgetTester tester, [int seconds = 1]) async {
  await tester.pump();
  await tester.pump(Duration(seconds: seconds));
}

double thumbX(WidgetTester tester) => tester.getCenter(thumb).dx;

void main() {
  testWidgets('renders with only the required arguments', (tester) async {
    await tester.pumpWidget(
      host(TideSlide(label: 'Slide to pay', onConfirmed: () {})),
    );
    expect(find.text('Slide to pay'), findsWidgets);
    expect(tester.getSize(find.byType(TideSlide)).height, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets('release before the threshold springs back', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++)),
    );
    final start = thumbX(tester);
    await drag(tester, travel * 0.5);
    await tester.pump(const Duration(milliseconds: 20));
    expect(thumbX(tester), greaterThan(start));
    await settle(tester, 2);
    expect(thumbX(tester), closeTo(start, 0.5));
    expect(calls, 0);
  });

  testWidgets(
    'slow drag past the threshold confirms once and shows the label',
    (tester) async {
      var calls = 0;
      final c = TideSlideController();
      await tester.pumpWidget(
        host(TideSlide(label: 'Go', onConfirmed: () => calls++, controller: c)),
      );
      await drag(tester, travel * 0.95);
      await settle(tester, 1);
      expect(calls, 1);
      expect(c.isConfirmed, isTrue);
      expect(find.text('Confirmed'), findsWidgets);
      final end =
          300 / 2 +
          150 -
          4 -
          24 +
          (tester.getTopLeft(find.byType(TideSlide)).dx - 0);
      expect(thumbX(tester), greaterThan(end - 60));
      // A further drag does nothing once confirmed.
      await drag(tester, -100);
      await settle(tester, 1);
      expect(calls, 1);
    },
  );

  testWidgets('fast fling versus slow drag', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++)),
    );
    await tester.fling(thumb, Offset(travel * 0.6, 0), 3000);
    await settle(tester, 1);
    expect(calls, 1, reason: 'fast fling past halfway confirms');

    calls = 0;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++)),
    );
    await tester.fling(thumb, Offset(travel * 0.3, 0), 3000);
    await settle(tester, 2);
    expect(calls, 0, reason: 'fast fling before halfway does not confirm');

    await tester.fling(thumb, Offset(travel * 0.6, 0), 200);
    await settle(tester, 2);
    expect(
      calls,
      0,
      reason: 'slow release below the threshold does not confirm',
    );
  });

  testWidgets('RTL: thumb starts at the right and slides left', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        TideSlide(label: 'Go', onConfirmed: () => calls++),
        dir: TextDirection.rtl,
      ),
    );
    final box = tester.getRect(find.byType(TideSlide));
    expect(thumbX(tester), greaterThan(box.center.dx));
    await drag(tester, travel * 0.5);
    await settle(tester, 2);
    expect(
      calls,
      0,
      reason: 'dragging toward the end of the screen does nothing',
    );
    await drag(tester, -travel * 0.95);
    await settle(tester, 1);
    expect(calls, 1);
  });

  testWidgets('resize mid-drag keeps the thumb on a valid position', (
    tester,
  ) async {
    var calls = 0;
    final width = ValueNotifier<double>(300);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (_, w, _) => Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: w,
                child: TideSlide(label: 'Go', onConfirmed: () => calls++),
              ),
            ),
          ),
        ),
      ),
    );
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 40));
    width.value = 200; // rotate or resize
    await tester.pump();
    expect(tester.takeException(), isNull);
    await g.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await g.up();
    await settle(tester, 1);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled ignores drags and is reported as disabled', (
    tester,
  ) async {
    var calls = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++, enabled: false)),
    );
    await drag(tester, travel);
    await settle(tester, 1);
    expect(calls, 0);
    final data = tester.getSemantics(find.byType(TideSlide)).getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.flagsCollection.isEnabled, isNot(Tristate.isTrue));
    handle.dispose();
  });

  testWidgets('loading prop shows a spinner and ignores drags', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++, loading: true)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await drag(tester, travel);
    await settle(tester, 1);
    expect(calls, 0);
  });

  testWidgets('async onConfirmed shows a spinner until it completes', (
    tester,
  ) async {
    final done = Completer<void>();
    final c = TideSlideController();
    await tester.pumpWidget(
      host(
        TideSlide(label: 'Go', onConfirmed: () => done.future, controller: c),
      ),
    );
    await drag(tester, travel);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(c.isLoading, isTrue);
    done.complete();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(c.isLoading, isFalse);
    expect(c.isConfirmed, isTrue);
  });

  testWidgets('a failing onConfirmed is reported and the control resets', (
    tester,
  ) async {
    final c = TideSlideController();
    await tester.pumpWidget(
      host(
        TideSlide(
          label: 'Go',
          controller: c,
          onConfirmed: () async => throw StateError('nope'),
        ),
      ),
    );
    await drag(tester, travel);
    await settle(tester, 1);
    expect(tester.takeException(), isA<StateError>());
    expect(c.isConfirmed, isFalse);
    await settle(tester, 1);
    expect(
      thumbX(tester),
      lessThan(tester.getRect(find.byType(TideSlide)).center.dx),
    );
  });

  testWidgets('semantics: label, button and a tap action that confirms', (
    tester,
  ) async {
    var calls = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(TideSlide(label: 'Slide to pay', onConfirmed: () => calls++)),
    );
    final data = tester.getSemantics(find.byType(TideSlide)).getSemanticsData();
    expect(data.label, 'Slide to pay');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Slide to pay'));
    await settle(tester, 1);
    expect(calls, 1);
    expect(
      tester.getSemantics(find.byType(TideSlide)).getSemanticsData().value,
      'Confirmed',
    );
    handle.dispose();
  });

  testWidgets('disposing during the confirm animation is safe', (tester) async {
    await tester.pumpWidget(host(TideSlide(label: 'Go', onConfirmed: () {})));
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(230, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await g.up();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing mid-spring-back is safe', (tester) async {
    await tester.pumpWidget(host(TideSlide(label: 'Go', onConfirmed: () {})));
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await g.up();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every option: threshold, height, colors, confirmedLabel', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        TideSlide(
          label: 'Go',
          threshold: 0.5,
          height: 72,
          confirmedLabel: 'Done',
          colors: const TideSlideColors(
            tide: Colors.purple,
            success: Colors.teal,
          ),
          onConfirmed: () => calls++,
        ),
      ),
    );
    expect(tester.getSize(find.byType(TideSlide)).height, 72);
    await drag(tester, 150); // travel is now 220, so 0.68
    await settle(tester, 1);
    expect(calls, 1);
    expect(find.text('Done'), findsWidgets);
  });

  testWidgets('invalid arguments are rejected in debug builds', (tester) async {
    expect(
      () => TideSlide(label: 'x', onConfirmed: () {}, threshold: 0),
      throwsAssertionError,
    );
    expect(
      () => TideSlide(label: 'x', onConfirmed: () {}, threshold: 1.5),
      throwsAssertionError,
    );
    expect(
      () => TideSlide(label: 'x', onConfirmed: () {}, height: 20),
      throwsAssertionError,
    );
  });

  testWidgets('controller: confirm, reset, swap and listeners', (tester) async {
    var calls = 0;
    var notified = 0;
    final c = TideSlideController()..addListener(() => notified++);
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++, controller: c)),
    );
    unawaited(c.confirm());
    await settle(tester, 1);
    expect(calls, 1);
    expect(c.isConfirmed, isTrue);
    expect(notified, greaterThan(0));
    unawaited(c.reset());
    await settle(tester, 1);
    expect(c.isConfirmed, isFalse);
    expect(
      thumbX(tester),
      lessThan(tester.getRect(find.byType(TideSlide)).center.dx),
    );

    final c2 = TideSlideController();
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++, controller: c2)),
    );
    unawaited(c.confirm()); // detached: no effect
    unawaited(c2.confirm());
    await settle(tester, 1);
    expect(calls, 2);
    expect(c2.isConfirmed, isTrue);
  });

  testWidgets('resetAfter returns the control to idle by itself', (
    tester,
  ) async {
    final c = TideSlideController();
    await tester.pumpWidget(
      host(
        TideSlide(
          label: 'Go',
          controller: c,
          resetAfter: const Duration(seconds: 2),
          onConfirmed: () {},
        ),
      ),
    );
    await drag(tester, travel);
    await settle(tester, 1);
    expect(c.isConfirmed, isTrue);
    await settle(tester, 3);
    expect(c.isConfirmed, isFalse);
  });

  testWidgets('keyboard: arrows step, enter confirms, home resets', (
    tester,
  ) async {
    var calls = 0;
    final c = TideSlideController();
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++, controller: c)),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester, 1);
    expect(calls, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () => calls++, controller: c)),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      thumbX(tester),
      closeTo(4 + 24 + tester.getTopLeft(find.byType(TideSlide)).dx, 1),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, 1);
    expect(calls, 2);
  });

  testWidgets('keyboard in RTL: the left arrow moves forward', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        TideSlide(label: 'Go', onConfirmed: () => calls++),
        dir: TextDirection.rtl,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    }
    await settle(tester, 1);
    expect(calls, 1);
  });

  testWidgets('reduced motion: no wave animation and a short return', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TideSlide(label: 'Go', onConfirmed: () {}), disableAnimations: true),
    );
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
    await g.up();
    await tester.pumpAndSettle();
    expect(
      thumbX(tester),
      closeTo(4 + 24 + tester.getTopLeft(find.byType(TideSlide)).dx, 1),
    );
  });

  testWidgets('wave runs while the tide is visible and stops at rest', (
    tester,
  ) async {
    await tester.pumpWidget(host(TideSlide(label: 'Go', onConfirmed: () {})));
    expect(tester.hasRunningAnimations, isFalse);
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await g.up();
    await settle(tester, 3);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('works at 320px with a very long label and no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TideSlide(
              label: 'Slide to confirm this very long transfer of funds today',
              onConfirmed: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(TideSlide)).width, 288);
  });

  testWidgets('unbounded width falls back to a fixed width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: TideSlide(label: 'Go', onConfirmed: () {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(TideSlide)).width, 300);
  });

  testWidgets('dispose leaves no running tickers or frames', (tester) async {
    await tester.pumpWidget(host(TideSlide(label: 'Go', onConfirmed: () {})));
    final g = await tester.startGesture(tester.getCenter(thumb));
    await g.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await tester.pumpWidget(const SizedBox());
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  group('golden', () {
    Future<void> shot(
      WidgetTester tester,
      String name, {
      ThemeData? theme,
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
            TideSlide(label: 'Slide to pay', onConfirmed: () {}),
            theme: theme,
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

    testWidgets(
      'default light',
      (t) => shot(t, 'default_light', theme: ThemeData(useMaterial3: true)),
    );
    testWidgets(
      'default dark',
      (t) => shot(
        t,
        'default_dark',
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      ),
    );
    testWidgets(
      'mid light',
      (t) => shot(
        t,
        'mid_light',
        theme: ThemeData(useMaterial3: true),
        dragBy: 110,
      ),
    );
    testWidgets(
      'confirmed dark',
      (t) => shot(
        t,
        'confirmed_dark',
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        confirm: true,
      ),
    );
  });
}
