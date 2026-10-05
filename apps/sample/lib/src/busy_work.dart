import 'package:flutter/widgets.dart';

/// How much longer than one frame budget the planted UI work takes.
///
/// Tuned so the plant visibly janks on both phones in M2. **(open, M4: tuned
/// per platform.)**
const double plantedWorkBudgets = 1.5;

/// Keeps the UI thread busy for [plantedWorkBudgets] frame budgets of the
/// screen [context] is shown on, like a synchronous decode of a large
/// message.
///
/// A fixed busy loop, not a real decode, so its cost is the same on every
/// phone at a given refresh rate.
///
/// A screen that reports no usable rate is treated as 60 Hz.
void busyForPlantedWork(BuildContext context) {
  final reported = View.of(context).display.refreshRate;
  final refreshRate = reported.isFinite && reported > 0 ? reported : 60;
  final budgetMicros = Duration.microsecondsPerSecond / refreshRate;
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsedMicroseconds < plantedWorkBudgets * budgetMicros) {}
}
