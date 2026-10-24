## 1.1.3

- README: the banner is no longer wrapped in a link, so pub.dev's dark-theme hover filter cannot wash it out, and the banner has stronger contrast. No code changes.

## 1.1.2

- README: Wiiby banner and HD (2x) demo, with absolute image links so the npm and pub.dev pages show them. No code changes.

## 1.1.1

- Package size: build outputs were included in the 1.1.0 archive by mistake.
- Zipper style now matches the approved design: teeth start just past the resting thumb and run to the end of the track, open rows sit 6 px from the edges and closed rows overlap by 1 px (on a 56 px track), and the label is centred over the teeth.
- Zipper confirm: the seam keeps its shape and turns the success colour, the track takes a success tint, and the thumb turns solid success with a tick. No confirmed text is drawn on the track.
- Zipper thumb is a solid tab with a two-by-three dot grip by default.

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
