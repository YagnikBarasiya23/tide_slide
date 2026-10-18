## 1.1.1

- Package size: build outputs were included in the 1.1.0 archive by mistake. No code changes.

## 1.1.0

- New zipper style: two rows of teeth mesh shut behind the thumb, open again on an early release, and seal in the success colour on confirm.
- `TideSlideStyle` enum and a `style` parameter (default `TideSlideStyle.tide`, so existing code is unchanged).
- `TideSlide.zipper(...)` named constructor.
- `toothSize` and `toothGap` options for the zipper style.
- Reduced motion in the zipper style: teeth switch with a hard cut at the thumb and the return is a short linear one.

## 1.0.0

- First release.
- `TideSlide` with a wavy tide that rises behind the thumb and a label that flips colour at the wave edge.
- Spring-back on early release, snap and tick on confirm, fling support.
- LTR and RTL, keyboard control, screen reader tap action, reduced-motion behaviour.
- Loading state (async `onConfirmed` or the `loading` flag), `enabled`, `resetAfter` and `TideSlideController`.
- Light and dark themes from `ThemeData`, with `TideSlideColors` overrides.
