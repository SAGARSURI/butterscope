import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/plant.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(SampleApp(plant: Plant.fromEnvironment()));
}

/// The sample app. M2 shows the calibration screen; M4 adds the sample
/// screens.
class SampleApp extends StatelessWidget {
  /// Creates the sample app with [plant] switched on, starting in [phase]'s
  /// value, or animated when [phase] is null.
  new({
    this.plant = Plant.none,
    ValueNotifier<CalibrationPhase>? phase,
    super.key,
  }) : phase = phase ?? ValueNotifier(CalibrationPhase.animated);

  final Plant plant;

  /// Which phase the calibration screen shows. A test sets it.
  final ValueNotifier<CalibrationPhase> phase;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CalibrationScreen(plant: plant, phase: phase),
    );
  }
}
