// Pure Dart, with no Flutter import, so host tools can use it too.

import 'package:butterscope/src/marks.dart';
import 'package:butterscope/src/recorded_window.dart';

/// The checks that decide whether a run or a span can be trusted
/// (`docs/DESIGN.md` section 7.2).
///
/// Each failure voids the run, except [declaredRateChange],
/// [tooFewVsyncs] and [openAtTestEnd], which void one span.
enum Guard {
  /// The app was built in debug mode.
  buildMode,

  /// A test ran under a frame policy other than `benchmarkLive`.
  framePolicy,

  /// The phone asked apps to turn animations off.
  animations,

  /// The text scale changed during the run.
  textScale,

  /// The locale changed during the run.
  locale,

  /// The phone was thermally limited, or could not say whether it was.
  thermal,

  /// Power saving or Low Power Mode was on.
  lowPower,

  /// The phone's state could not be read: the app was built without
  /// Butterscope's plugin.
  deviceState,

  /// The screen declared a refresh rate of 0 or one that is not finite.
  declaredRate,

  /// The declared rate inside a span moved more than 5% from its start.
  declaredRateChange,

  /// A span lasted fewer than [minimumSpanVsyncs] vsyncs.
  tooFewVsyncs,

  /// A span was still open when its test ended.
  openAtTestEnd,
}

/// The fewest vsyncs a span must last: the 11 frames one rate slice needs
/// for its 10 gaps (`docs/decisions/0001-metric-definitions.md` item 6).
///
/// Elapsed vsyncs count the frames drawn and the vsyncs that passed
/// without one, so a span that janks badly is not voided for drawing few
/// frames.
const int minimumSpanVsyncs = 11;

/// How far, as a share of the starting rate, a declared rate may move
/// inside a span.
const double _rateTolerance = 0.05;

/// One guard that failed, where and with what value.
final class GuardFailure {
  /// Creates a failure of [guard], seen [at], with the [value] read.
  const new(this.guard, this.at, [this.value]);

  /// The guard that failed.
  final Guard guard;

  /// Where it was seen, such as `run start` or `start of <test name>`.
  final String at;

  /// The value read, such as `serious` or `0.0`, when it says more than
  /// the guard's name.
  final String? value;

  /// The failure as `[guard, at]` or `[guard, at, value]`.
  List<Object?> toJson() => [guard.name, at, ?value];
}

/// Whether the declared rate moved more than 5% from [part]'s start
/// within it: at its end mark, or in a read taken between its first and
/// last timings.
///
/// A rate that is not finite counts as moved.
bool declaredRateChanged(MarkedPart part, RecordedWindow window) {
  final first = part.start.declaredRefreshRate;
  final rates = [
    part.end.declaredRefreshRate,
    for (final read in window.readsBetween(part.start, part.end)) read.hertz,
  ];
  // Written as "not within" so that NaN counts as moved.
  return rates.any(
    (hertz) => !((hertz - first).abs() <= first * _rateTolerance),
  );
}
