/// Multi-touch handling policies when secondary pointers contact the screen.
enum MultiTouchPolicy {
  /// Completes and commits the active stroke up to the last valid single-finger
  /// sample, then transitions to multi-touch gesture mode. (Recommended default)
  completeCurrentStroke,

  /// Aborts and discards the active stroke when a second finger appears.
  cancelCurrentStroke,

  /// Ignores secondary fingers and continues tracking only the primary pointer.
  ignoreSecondaryPointers,
}

/// State tracking for pointer interaction mode.
enum PointerInputState {
  /// Canvas is idle, ready for interaction.
  idle,

  /// A single pointer is actively drawing.
  drawing,

  /// Two or more pointers are active on screen (e.g. pinch, pan, zoom gesture).
  multitouch,
}
