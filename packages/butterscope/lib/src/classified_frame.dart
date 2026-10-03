import 'dart:math' as math;

import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';

/// How late a frame was, from best to worst.
///
/// The classes nest: every stall is severe and every severe frame is janky.
enum FrameClass {
  /// Both threads fit the budget.
  smooth,

  /// A thread took longer than the budget: at least one vsync was missed.
  janky,

  /// The slower thread took more than twice the budget: a visible hitch.
  severe,

  /// A severe frame that took 100 ms or more: a freeze people notice.
  stall;

  /// Whether this class is [other] or worse.
  bool isAtLeast(FrameClass other) => index >= other.index;
}

/// The thread that made a janky frame late.
enum JankThread {
  /// Only the UI thread, which runs Dart code, was over budget: building
  /// the frame, or other work that kept the frame waiting to start.
  ui,

  /// Only the raster thread, which draws the frame, was over budget.
  raster,

  /// Both threads were over budget.
  both,
}

/// A frame judged against a budget.
final class ClassifiedFrame {
  /// Judges [sample] against [budget].
  const new(this.sample, this.budget);

  /// A severe frame this long or longer is a stall, whatever the screen.
  static const int stallMicros = 100000;

  /// The frame being judged.
  final FrameSample sample;

  /// The budget it is judged against.
  final FrameBudget budget;

  /// UI thread time in microseconds: the wait for the UI thread after the
  /// vsync plus the build.
  ///
  /// The UI thread cannot start the next frame until this one is built, so
  /// UI time over the budget means a vsync was missed, whatever caused the
  /// wait. A negative wait, which a well-behaved engine never reports,
  /// counts as none.
  int get uiMicros {
    final wait = math.max(0, sample.vsyncOverheadMicros);
    return wait + sample.buildMicros;
  }

  /// The slower thread's time in microseconds.
  int get slowestMicros => math.max(uiMicros, sample.rasterMicros);

  /// How late the frame was in microseconds: the slower thread's time minus
  /// the budget. Negative when the frame had time to spare.
  double get overrunMicros => slowestMicros - budget.micros;

  /// The UI time as a multiple of the budget.
  double get uiMultiple => uiMicros / budget.micros;

  /// The raster time as a multiple of the budget.
  double get rasterMultiple => sample.rasterMicros / budget.micros;

  /// The frame's class.
  FrameClass get frameClass {
    final slowest = slowestMicros;
    final budgetMicros = budget.micros;
    if (slowest <= budgetMicros) return FrameClass.smooth;
    if (slowest <= 2 * budgetMicros) return FrameClass.janky;
    if (slowest < stallMicros) return FrameClass.severe;
    return FrameClass.stall;
  }

  /// The thread that was over budget, or `null` for a smooth frame.
  JankThread? get thread {
    final uiLate = uiMicros > budget.micros;
    final rasterLate = sample.rasterMicros > budget.micros;
    if (uiLate && rasterLate) return JankThread.both;
    if (uiLate) return JankThread.ui;
    if (rasterLate) return JankThread.raster;
    return null;
  }
}
