/// Decides whether releasing the thumb confirms the action.
///
/// [progress] is the thumb position from 0 to 1. [velocity] is the release
/// speed in logical pixels per second, positive when moving toward the end of
/// the track. A slow drag must reach [threshold]. A fast forward fling also
/// confirms once the thumb is past the halfway point.
bool shouldConfirm({
  required double progress,
  required double velocity,
  required double threshold,
  required double flingVelocity,
}) {
  if (progress >= threshold) return true;
  return velocity >= flingVelocity && progress >= 0.5;
}
