import 'dart:io';

import 'package:butterscope/butterscope.dart' show ButterscopeRouteObserver;
import 'package:butterscope_sample/src/activity/activity_source.dart';
import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/home_shell.dart';
import 'package:butterscope_sample/src/inbox/inbox_socket.dart';
import 'package:butterscope_sample/src/no_network.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/plant_costs.dart';
import 'package:flutter/material.dart';

void main() {
  HttpOverrides.global = NoNetworkHttpOverrides();
  runApp(
    SampleApp(
      inbox: InboxSocket(headers: syncDecodeHeaders.value),
      plant: Plant.fromEnvironment(),
      overlay: SampleApp.overlayFromName(
        const String.fromEnvironment('BUTTERSCOPE_OVERLAY'),
      ),
    ),
  );
}

/// The sample app: a catalogue of items, browsed on several screens.
///
/// M2's calibration screen is at [calibrationRoute]; open it with
/// `flutter run --route=/calibration`.
class SampleApp extends StatelessWidget {
  /// Creates the app over [catalogue], or the seeded catalogue when it is
  /// null, with [plant] switched on. [activity] and [inbox] stand in for
  /// the server's live feeds. [overlay] shows Flutter's performance overlay.
  new({
    Catalogue? catalogue,
    this.activity = const ActivitySource(),
    this.inbox = const InboxSocket(),
    this.plant = Plant.none,
    this.overlay = false,
    super.key,
  }) : catalogue = catalogue ?? Catalogue.seeded();

  /// The route of M2's calibration screen.
  static const calibrationRoute = '/calibration';

  final Catalogue catalogue;
  final ActivitySource activity;
  final InboxSocket inbox;
  final Plant plant;
  final bool overlay;

  /// Reads `BUTTERSCOPE_OVERLAY`: "on" shows the overlay, and an empty
  /// value, as in a build without the define, hides it.
  ///
  /// Throws an [ArgumentError] for any other value, so a typo fails loudly
  /// instead of making a build without the overlay.
  static bool overlayFromName(String name) {
    return switch (name) {
      'on' => true,
      '' => false,
      _ => throw ArgumentError.value(
        name,
        'BUTTERSCOPE_OVERLAY',
        'is not "on"',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PlantScope(
      plant: plant,
      child: MaterialApp(
        title: 'Catalogue',
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        showPerformanceOverlay: overlay,
        // Tags Butterscope's episodes with the page on top while tests
        // record; it does nothing otherwise.
        navigatorObservers: [ButterscopeRouteObserver()],
        home: HomeShell(catalogue: catalogue, activity: activity, inbox: inbox),
        routes: {
          calibrationRoute: (_) => CalibrationScreen(
            plant: plant,
            phase: ValueNotifier(CalibrationPhase.animated),
          ),
        },
      ),
    );
  }
}
