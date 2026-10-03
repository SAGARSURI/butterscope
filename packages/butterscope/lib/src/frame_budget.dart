/// The time one frame may take on a screen: `B` in `docs/DESIGN.md`.
///
/// `B = 1000 / refreshRate` milliseconds: 16.67 ms at 60 Hz, 8.33 ms at
/// 120 Hz. Every gate metric is measured against it, so one threshold holds
/// on every screen.
final class FrameBudget {
  /// Creates the budget for a screen that refreshes [refreshRate] times a
  /// second.
  ///
  /// Throws an [ArgumentError] when [refreshRate] is not a positive, finite
  /// number.
  new(double refreshRate) : refreshRate = _checked(refreshRate);

  /// The screen's refresh rate in hertz.
  final double refreshRate;

  /// The budget in microseconds, the unit `FrameTiming` reports in.
  double get micros => Duration.microsecondsPerSecond / refreshRate;

  /// The budget in milliseconds.
  double get millis => Duration.millisecondsPerSecond / refreshRate;

  static double _checked(double refreshRate) {
    if (!refreshRate.isFinite || refreshRate <= 0) {
      throw ArgumentError.value(
        refreshRate,
        'refreshRate',
        'must be a positive, finite number of hertz',
      );
    }
    return refreshRate;
  }
}
