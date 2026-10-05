import 'dart:io';

import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/home_shell.dart';
import 'package:butterscope_sample/src/no_network.dart';
import 'package:butterscope_sample/src/plant.dart';
import 'package:flutter/material.dart';

void main() {
  HttpOverrides.global = NoNetworkHttpOverrides();
  runApp(SampleApp(plant: Plant.fromEnvironment()));
}

/// The sample app: a catalogue of items, browsed on several screens.
///
/// M2's calibration screen is at [calibrationRoute]; open it with
/// `flutter run --route=/calibration`.
class SampleApp extends StatelessWidget {
  /// Creates the app over [catalogue], or the seeded catalogue when it is
  /// null, with [plant] switched on.
  new({Catalogue? catalogue, this.plant = Plant.none, super.key})
    : catalogue = catalogue ?? Catalogue.seeded();

  /// The route of M2's calibration screen.
  static const calibrationRoute = '/calibration';

  final Catalogue catalogue;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catalogue',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: HomeShell(catalogue: catalogue),
      routes: {
        calibrationRoute: (_) => CalibrationScreen(
          plant: plant,
          phase: ValueNotifier(CalibrationPhase.animated),
        ),
      },
    );
  }
}
