import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'glyphs.dart';
import 'release_logic.dart';
import 'tide_path.dart';
import 'tide_slide_colors.dart';
import 'zipper_painter.dart';

/// The look of a [TideSlide]. Behaviour is the same for every style.
enum TideSlideStyle {
  /// A wavy tide of colour rises behind the thumb. The default.
  tide,

  /// Two rows of teeth mesh shut behind the thumb, like a zipper.
  zipper,
}

enum _Phase { idle, dragging, settling, loading, confirmed }

const double _inset = 4;
const double _steps = 0.1;

/// Lets the parent read the state of a [TideSlide] and drive it.
///
/// Attach it with [TideSlide.controller]. It does nothing until attached and
/// after the widget is disposed.
class TideSlideController extends ChangeNotifier {
  Future<void> Function()? _reset;
  Future<void> Function()? _confirm;
  bool _isConfirmed = false;
  bool _isLoading = false;

  /// True once the thumb has been confirmed and until [reset].
  bool get isConfirmed => _isConfirmed;

  /// True while an asynchronous `onConfirmed` is running.
  bool get isLoading => _isLoading;

  /// Returns the control to its idle state.
  Future<void> reset() => _reset?.call() ?? Future<void>.value();

  /// Confirms programmatically, exactly as if the thumb reached the end.
  Future<void> confirm() => _confirm?.call() ?? Future<void>.value();

  void _sync(bool confirmed, bool loading) {
    if (confirmed == _isConfirmed && loading == _isLoading) return;
    _isConfirmed = confirmed;
    _isLoading = loading;
    notifyListeners();
  }
}

/// A slide-to-confirm control for risky actions.
///
/// Drag the thumb along the track. A wavy tide of colour rises behind it and
/// the label flips colour exactly where the tide passes. Release before
/// [threshold] and the thumb springs back. Past it, the thumb snaps to the
/// end, [onConfirmed] is called and a tick is drawn.
class TideSlide extends StatefulWidget {
  /// Creates a slide-to-confirm control.
  const TideSlide({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.threshold = 0.85,
    this.height = 56,
    this.colors,
    this.controller,
    this.enabled = true,
    this.loading = false,
    this.confirmedLabel = 'Confirmed',
    this.flingVelocity = 1200,
    this.resetAfter,
    this.style = TideSlideStyle.tide,
    this.toothSize = 6,
    this.toothGap = 4,
  }) : assert(threshold > 0 && threshold <= 1, 'threshold must be in (0, 1]'),
       assert(height >= 40, 'height must be at least 40'),
       assert(flingVelocity > 0, 'flingVelocity must be positive'),
       assert(toothSize > 0, 'toothSize must be positive'),
       assert(toothGap >= 0, 'toothGap must not be negative');

  /// Creates a slide-to-confirm control in the [TideSlideStyle.zipper] style.
  const TideSlide.zipper({
    Key? key,
    required String label,
    required FutureOr<void> Function() onConfirmed,
    double threshold = 0.85,
    double height = 56,
    TideSlideColors? colors,
    TideSlideController? controller,
    bool enabled = true,
    bool loading = false,
    String confirmedLabel = 'Confirmed',
    double flingVelocity = 1200,
    Duration? resetAfter,
    double toothSize = 6,
    double toothGap = 4,
  }) : this(
         key: key,
         label: label,
         onConfirmed: onConfirmed,
         threshold: threshold,
         height: height,
         colors: colors,
         controller: controller,
         enabled: enabled,
         loading: loading,
         confirmedLabel: confirmedLabel,
         flingVelocity: flingVelocity,
         resetAfter: resetAfter,
         style: TideSlideStyle.zipper,
         toothSize: toothSize,
         toothGap: toothGap,
       );

  /// Text on the track, for example "Slide to pay".
  final String label;

  /// Called when the action is confirmed. If it returns a [Future], the thumb
  /// shows a spinner until it completes. If that future throws, the error is
  /// reported and the control resets.
  final FutureOr<void> Function() onConfirmed;

  /// How far the thumb must travel, from 0 to 1, for a slow drag to confirm.
  final double threshold;

  /// Track height in logical pixels. The thumb is 8 pixels smaller.
  final double height;

  /// Colour overrides. Anything left null follows the theme.
  final TideSlideColors? colors;

  /// Optional controller for reset and programmatic confirm.
  final TideSlideController? controller;

  /// When false the control is dimmed and ignores input.
  final bool enabled;

  /// Shows a spinner on the thumb and ignores input, for work you track yourself.
  final bool loading;

  /// Label shown after confirming. Also announced by screen readers.
  final String confirmedLabel;

  /// Forward release speed, in logical pixels per second, that confirms a
  /// short drag once the thumb is past halfway.
  final double flingVelocity;

  /// If set, the control resets by itself this long after confirming.
  final Duration? resetAfter;

  /// The look of the track. Defaults to [TideSlideStyle.tide].
  final TideSlideStyle style;

  /// Width and height of one zipper tooth. Only used by the zipper style.
  final double toothSize;

  /// Space between neighbouring zipper teeth. Only used by the zipper style.
  final double toothGap;

  @override
  State<TideSlide> createState() => _TideSlideState();
}

class _TideSlideState extends State<TideSlide> with TickerProviderStateMixin {
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: 0,
  )..addListener(_syncWave);
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _tick =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 360),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _wave.stop();
      });

  final FocusNode _focus = FocusNode(debugLabel: 'TideSlide');
  _Phase _phase = _Phase.idle;
  Timer? _resetTimer;
  double _travel = 1;
  bool _rtl = false;
  bool _reduced = false;
  bool _focused = false;

  bool get _interactive => widget.enabled && !widget.loading;
  bool get _canStart =>
      _interactive && (_phase == _Phase.idle || _phase == _Phase.dragging);
  double get _progress => _pos.value.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduced) _wave.stop();
  }

  @override
  void didUpdateWidget(TideSlide old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _detach(old.controller);
      _attach(widget.controller);
    }
    if (!widget.enabled && _phase == _Phase.dragging) _springBack(0);
    if (old.style != widget.style) _syncWave();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _detach(widget.controller);
    _pos.dispose();
    _wave.dispose();
    _tick.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _attach(TideSlideController? c) {
    if (c == null) return;
    c._reset = _reset;
    c._confirm = _confirm;
    c._isConfirmed = _phase == _Phase.confirmed;
    c._isLoading = _phase == _Phase.loading;
  }

  void _detach(TideSlideController? c) {
    if (c == null) return;
    c._reset = null;
    c._confirm = null;
  }

  void _setPhase(_Phase p) {
    _phase = p;
    widget.controller?._sync(p == _Phase.confirmed, p == _Phase.loading);
    if (mounted) setState(() {});
  }

  void _syncWave() {
    final shouldRun =
        widget.style == TideSlideStyle.tide &&
        !_reduced &&
        _phase != _Phase.confirmed &&
        _pos.value > 0.001;
    if (shouldRun && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!shouldRun && _wave.isAnimating) {
      _wave.stop();
    }
  }

  /* ---------- gestures ---------- */

  void _onDragStart(DragStartDetails d) {
    if (!_canStart) return;
    _pos.stop();
    _setPhase(_Phase.dragging);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_phase != _Phase.dragging) return;
    final delta = (d.primaryDelta ?? 0) * (_rtl ? -1 : 1);
    _pos.value = (_pos.value + delta / _travel).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_phase != _Phase.dragging) return;
    final v = (d.primaryVelocity ?? 0) * (_rtl ? -1 : 1);
    final go = shouldConfirm(
      progress: _progress,
      velocity: v,
      threshold: widget.threshold,
      flingVelocity: widget.flingVelocity,
    );
    if (go) {
      _confirm();
    } else {
      _springBack(v / _travel);
    }
  }

  void _onDragCancel() {
    if (_phase == _Phase.dragging) _springBack(0);
  }

  /* ---------- state transitions ---------- */

  Future<void> _springBack(double velocity) async {
    _setPhase(_Phase.idle);
    if (_reduced) {
      await _pos.animateTo(
        0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.linear,
      );
    } else {
      final spring = SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 420,
        ratio: 0.72,
      );
      await _pos.animateWith(SpringSimulation(spring, _pos.value, 0, velocity));
    }
    if (mounted &&
        _phase == _Phase.idle &&
        _pos.value != 0 &&
        !_pos.isAnimating) {
      _pos.value = 0;
    }
  }

  Future<void> _confirm() async {
    final startable = _phase == _Phase.idle || _phase == _Phase.dragging;
    if (!_interactive || !startable) return;
    _pos.stop();
    _setPhase(_Phase.settling);
    await _pos.animateTo(
      1,
      duration: _reduced
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || _phase != _Phase.settling) return;

    final result = widget.onConfirmed();
    if (result is Future<void>) {
      _setPhase(_Phase.loading);
      try {
        await result;
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'tide_slide',
            context: ErrorDescription('while running onConfirmed'),
          ),
        );
        if (mounted && _phase == _Phase.loading) await _reset();
        return;
      }
      if (!mounted || _phase != _Phase.loading) return;
    }
    _setPhase(_Phase.confirmed);
    _tick.duration = _reduced
        ? const Duration(milliseconds: 1)
        : const Duration(milliseconds: 360);
    _tick.forward(from: 0);
    final after = widget.resetAfter;
    if (after != null) {
      _resetTimer?.cancel();
      _resetTimer = Timer(after, () {
        if (mounted) _reset();
      });
    }
  }

  Future<void> _reset() async {
    if (!mounted) return;
    _resetTimer?.cancel();
    _pos.stop();
    _tick.value = 0;
    _setPhase(_Phase.idle);
    if (_pos.value <= 0) return;
    await _pos.animateTo(
      0,
      duration: _reduced
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _stepTo(double value) {
    if (!_canStart) return;
    _pos.stop();
    _pos.value = value.clamp(0.0, 1.0);
    if (_progress >= widget.threshold) {
      _confirm();
    } else if (_phase != _Phase.idle) {
      _setPhase(_Phase.idle);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_canStart) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final forward = _rtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    final back = _rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _confirm();
      return KeyEventResult.handled;
    }
    if (key == forward) {
      _stepTo(_progress + _steps);
      return KeyEventResult.handled;
    }
    if (key == back) {
      _stepTo(_progress - _steps);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _stepTo(0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /* ---------- build ---------- */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _resolveColors(theme);
    _rtl = Directionality.of(context) == TextDirection.rtl;
    final h = widget.height;
    final thumbSize = h - 2 * _inset;
    final labelStyle = (theme.textTheme.labelLarge ?? const TextStyle())
        .copyWith(fontWeight: FontWeight.w600);
    final confirmed = _phase == _Phase.confirmed;

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      value: confirmed ? widget.confirmedLabel : null,
      onTap: _interactive ? _confirm : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.5,
        child: Focus(
          focusNode: _focus,
          canRequestFocus: _interactive,
          onKeyEvent: _onKey,
          onFocusChange: (f) => setState(() => _focused = f),
          child: LayoutBuilder(
            builder: (context, cons) {
              final w = cons.hasBoundedWidth ? cons.maxWidth : 300.0;
              _travel = math.max(1.0, w - thumbSize - 2 * _inset);
              return SizedBox(
                width: w,
                height: h,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pos, _wave, _tick]),
                  builder: (context, _) => _buildTrack(
                    context,
                    colors,
                    labelStyle,
                    Size(w, h),
                    thumbSize,
                    confirmed,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTrack(
    BuildContext context,
    ResolvedTideColors c,
    TextStyle labelStyle,
    Size size,
    double thumbSize,
    bool confirmed,
  ) {
    final p = _progress;
    final t = Curves.easeOut.transform(_tick.value);
    final text = confirmed ? widget.confirmedLabel : widget.label;

    Widget label(Color color) => Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.height),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle.copyWith(color: color),
        ),
      ),
    );

    final zipper = widget.style == TideSlideStyle.zipper;
    final layers = switch (widget.style) {
      TideSlideStyle.tide => _tideLayers(c, size, thumbSize, p, t, label),
      TideSlideStyle.zipper => _zipperLayers(c, size, thumbSize, p, t),
    };

    final showSpinner = widget.loading || _phase == _Phase.loading;

    Widget glyph;
    if (showSpinner) {
      glyph = Padding(
        padding: EdgeInsets.all(thumbSize * 0.28),
        child: CircularProgressIndicator(strokeWidth: 2.4, color: c.thumbIcon),
      );
    } else if (confirmed) {
      glyph = CustomPaint(
        painter: CheckPainter(
          color: zipper ? c.onSuccess : c.success,
          progress: _tick.value,
        ),
      );
    } else if (zipper) {
      glyph = CustomPaint(painter: GripPainter(color: c.thumbIcon));
    } else {
      glyph = CustomPaint(
        painter: ChevronsPainter(color: c.thumbIcon, rtl: _rtl),
      );
    }

    final thumb = PositionedDirectional(
      start: _inset + p * _travel,
      top: _inset,
      width: thumbSize,
      height: thumbSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: zipper ? Color.lerp(c.thumb, c.success, t) : c.thumb,
            border: _focused
                ? Border.all(color: c.tide, width: 2.5)
                : Border.all(color: c.border, width: 1),
          ),
          child: glyph,
        ),
      ),
    );

    final successTrack = Color.alphaBlend(
      c.success.withValues(alpha: 0.18),
      c.track,
    );
    final successBorder = c.success.withValues(alpha: 0.45);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: zipper ? Color.lerp(c.track, successTrack, t) : c.track,
        borderRadius: BorderRadius.circular(size.height / 2),
        border: Border.all(
          color: zipper ? Color.lerp(c.border, successBorder, t)! : c.border,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size.height / 2),
        child: Stack(children: [...layers, thumb]),
      ),
    );
  }

  List<Widget> _tideLayers(
    ResolvedTideColors c,
    Size size,
    double thumbSize,
    double p,
    double t,
    Widget Function(Color) label,
  ) {
    final thumbEdge = p <= 0.0005 ? 0.0 : p * _travel + _inset + thumbSize / 2;
    final edge = _lerp(thumbEdge, size.width + 12, t);
    final amplitude = _reduced
        ? 0.0
        : math.min(1.0, p * 8) * (size.height * 0.09) * (1 - t);
    final path = buildTidePath(
      size,
      edge: edge,
      phase: _wave.value * 2 * math.pi,
      amplitude: amplitude,
      wavelength: size.height * 0.9,
      rtl: _rtl,
    );
    final tideColor = Color.lerp(c.tide, c.success, t)!;
    final onTide = Color.lerp(c.onTide, c.onSuccess, t)!;
    return [
      Positioned.fill(child: label(c.label)),
      Positioned.fill(
        child: CustomPaint(painter: FillPathPainter(path, tideColor)),
      ),
      Positioned.fill(
        child: ClipPath(clipper: PathClipper(path), child: label(onTide)),
      ),
    ];
  }

  List<Widget> _zipperLayers(
    ResolvedTideColors c,
    Size size,
    double thumbSize,
    double p,
    double t,
  ) {
    final h = size.height;
    return [
      Positioned.fill(
        child: CustomPaint(
          painter: ZipperPainter(
            thumbCenter: _inset + p * _travel + thumbSize / 2,
            toothSize: widget.toothSize,
            toothGap: widget.toothGap,
            openColor: c.label.withValues(alpha: 0.45),
            closedColor: c.tide,
            successColor: c.success,
            rtl: _rtl,
            reduced: _reduced,
            success: t,
          ),
        ),
      ),
      // The label sits centred over the teeth and is only drawn ahead of the
      // thumb, so it is gone once the thumb reaches the end.
      Positioned.fill(
        child: ClipRect(
          clipper: AheadClipper(
            leading: _inset + p * _travel + thumbSize,
            rtl: _rtl,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: h, end: h * 0.25),
            child: Center(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle(context).copyWith(color: c.label),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  TextStyle _labelStyle(BuildContext context) =>
      (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
      );

  ResolvedTideColors _resolveColors(ThemeData theme) {
    final given = widget.colors ?? const TideSlideColors();
    final c = given.resolve(theme);
    if (widget.style != TideSlideStyle.zipper) return c;
    // The zipper pull reads best as a solid dark (or light, in dark mode) tab.
    final scheme = theme.colorScheme;
    return ResolvedTideColors(
      track: c.track,
      border: c.border,
      tide: c.tide,
      onTide: c.onTide,
      thumb: given.thumb ?? scheme.onSurface,
      thumbIcon: given.thumbIcon ?? scheme.surface,
      label: c.label,
      success: c.success,
      onSuccess: c.onSuccess,
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
