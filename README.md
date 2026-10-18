# tide_slide

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![pub package](https://img.shields.io/pub/v/tide_slide.svg)](https://pub.dev/packages/tide_slide)

A slide-to-confirm control for risky actions. Drag the thumb and a wavy tide of colour rises behind it. The label flips colour exactly where the wave passes. Let go early and the thumb springs back. Pull it past the threshold and it snaps to the end, runs your callback and draws a tick.

![Demo](media/demo.gif)

## Install

```yaml
dependencies:
  tide_slide: ^1.1.1
```

## Usage

```dart
import 'package:tide_slide/tide_slide.dart';

TideSlide(
  label: 'Slide to pay',
  onConfirmed: () => pay(),
)
```

An async callback shows a spinner on the thumb until it completes:

```dart
final controller = TideSlideController();

TideSlide(
  label: 'Slide to send',
  confirmedLabel: 'Sent',
  controller: controller,
  onConfirmed: () async {
    await api.send();
  },
);

// later
controller.reset();
```

If the future throws, the error is reported with `FlutterError.reportError` and the control resets.

## Styles

Two looks share the same behaviour, options and controller.

| Style | Look |
|---|---|
| `TideSlideStyle.tide` (default) | A wavy tide rises behind the thumb and the label flips colour at the wave. |
| `TideSlideStyle.zipper` | Two rows of teeth mesh shut behind a zipper-pull thumb. Let go early and they open again. On confirm the seam, track and thumb turn the success colour and the thumb shows a tick. No confirmed text is drawn; `confirmedLabel` is still announced to screen readers. |

```dart
TideSlide.zipper(
  label: 'Slide to seal',
  confirmedLabel: 'Sealed',
  onConfirmed: () => seal(),
)

// same as
TideSlide(
  style: TideSlideStyle.zipper,
  label: 'Slide to seal',
  onConfirmed: () => seal(),
)
```

![Zipper demo](media/zipper.gif)

## Options

| Parameter | Default | Description |
|---|---|---|
| `label` | required | Text on the track. |
| `onConfirmed` | required | `FutureOr<void> Function()`. A returned `Future` drives the loading state. |
| `threshold` | `0.85` | Travel from 0 to 1 that a slow drag must reach. |
| `height` | `56` | Track height (at least 40). The thumb is 8 smaller. |
| `colors` | theme | A `TideSlideColors`. Null fields follow `ThemeData`. |
| `controller` | none | A `TideSlideController`. |
| `enabled` | `true` | When false the control is dimmed and ignores input. |
| `loading` | `false` | Shows the spinner and ignores input. |
| `confirmedLabel` | `'Confirmed'` | Label after confirming, also read by screen readers. |
| `flingVelocity` | `1200` | Forward release speed (px/s) that confirms a short drag once past halfway. |
| `resetAfter` | none | Resets by itself this long after confirming. |
| `style` | `TideSlideStyle.tide` | `tide` or `zipper`. |
| `toothSize` | `6` | Zipper only. Width and height of one tooth. |
| `toothGap` | `4` | Zipper only. Space between teeth in a row. |

`TideSlideController`: `reset()`, `confirm()`, `isConfirmed`, `isLoading`. It is a `ChangeNotifier`, so you can listen to it.

`TideSlideColors`: `track`, `border`, `tide`, `onTide`, `thumb`, `thumbIcon`, `label`, `success`, `onSuccess`. In the zipper style, `tide` colours the closed teeth.

The control takes its width from its parent. In an unbounded width it falls back to 300.

## Accessibility

- Screen readers get a button with your label. Activating it (double tap) confirms directly, so no drag is needed.
- Keyboard: Tab to focus. Arrow keys move the thumb in steps of 10 percent (the arrow that points toward the end moves forward, also in RTL). Enter or Space confirms. Home resets the thumb.
- Reduced motion (`MediaQuery.disableAnimations`): the wave stops moving, zipper teeth switch with a hard cut instead of easing, and the spring-back becomes a short linear return.
- Right-to-left layouts mirror the thumb, tide, teeth and chevrons.

## Platforms

Pure Dart and Flutter widgets with no plugins, so it runs on every Flutter platform. The widget tests cover LTR, RTL, resize mid-drag, a 320 px width, keyboard, semantics, reduced motion and dispose safety. Goldens cover the light and dark themes.

## Example

See [example/](example/). Run it with:

```bash
cd example
flutter run -d chrome
```

## Licence

MIT. See [LICENSE](LICENSE).
