/// The time one frame may take on a screen: `B` in `docs/DESIGN.md`.
///
/// `B = 1000 / refreshRate` milliseconds: 16.67 ms at 60 Hz, 8.33 ms at
/// 120 Hz. Every gate metric is measured against it, so one threshold holds
/// on every screen.
final class FrameBudget {
  /// Creates the budget for a screen that refreshes [refreshRate] times a
  /// second.
  ///
  /// Throws an [ArgumentError] when [refreshRate] is not a valid rate (see
  /// [isValidRefreshRate]). A recorder checks first and makes the run
  /// `INVALID` instead, because a screen can report 0 when its rate is not
  /// known.
  new(double refreshRate) : refreshRate = _checked(refreshRate);

  /// The screen's refresh rate in hertz.
  final double refreshRate;

  /// The budget in microseconds, the unit `FrameTiming` reports in.
  double get micros => Duration.microsecondsPerSecond / refreshRate;

  /// The budget in milliseconds.
  double get millis => Duration.millisecondsPerSecond / refreshRate;

  /// Whether [refreshRate] can give a budget: a positive, finite number of
  /// hertz.
  static bool isValidRefreshRate(double refreshRate) {
    return refreshRate.isFinite && refreshRate > 0;
  }

  static double _checked(double refreshRate) {
    if (!isValidRefreshRate(refreshRate)) {
      throw ArgumentError.value(
        refreshRate,
        'refreshRate',
        'must be a positive, finite number of hertz',
      );
    }
    return refreshRate;
  }
}
