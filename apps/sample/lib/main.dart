import 'dart:io';

import 'package:butterscope_sample/src/activity/activity_source.dart';
import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/home_shell.dart';
import 'package:butterscope_sample/src/inbox/inbox_socket.dart';
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
  /// null, with [plant] switched on. [activity] and [inbox] stand in for
  /// the server's live feeds.
  new({
    Catalogue? catalogue,
    this.activity = const ActivitySource(),
    this.inbox = const InboxSocket(),
    this.plant = Plant.none,
    super.key,
  }) : catalogue = catalogue ?? Catalogue.seeded();

  /// The route of M2's calibration screen.
  static const calibrationRoute = '/calibration';

  final Catalogue catalogue;
  final ActivitySource activity;
  final InboxSocket inbox;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catalogue',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: HomeShell(catalogue: catalogue, activity: activity, inbox: inbox),
      routes: {
        calibrationRoute: (_) => CalibrationScreen(
          plant: plant,
          phase: ValueNotifier(CalibrationPhase.animated),
        ),
      },
    );
  }
}
