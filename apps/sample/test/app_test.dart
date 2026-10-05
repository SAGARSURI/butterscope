import 'dart:io';

import 'package:butterscope_sample/main.dart';
import 'package:butterscope_sample/src/activity/activity_screen.dart';
import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/feed/feed_screen.dart';
import 'package:butterscope_sample/src/gallery/gallery_screen.dart';
import 'package:butterscope_sample/src/inbox/inbox_screen.dart';
import 'package:butterscope_sample/src/no_network.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/raster_plants.dart';
import 'package:butterscope_sample/src/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

void main() {
  testWidgets('opens on the feed and switches screens', (tester) async {
    await tester.pumpWidget(SampleApp(catalogue: smallCatalogue));
    expect(find.byType(FeedScreen), findsOneWidget);

    for (final (label, screen) in [
      ('Search', SearchScreen),
      ('Activity', ActivityScreen),
      ('Inbox', InboxScreen),
      ('Gallery', GalleryScreen),
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      expect(find.byType(screen), findsOneWidget, reason: label);
    }
    expect(find.byType(FeedScreen), findsNothing);
  });

  testWidgets('the calibration route shows the calibration screen', (
    tester,
  ) async {
    await tester.pumpWidget(SampleApp(catalogue: smallCatalogue));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(SampleApp.calibrationRoute).ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CalibrationScreen), findsOneWidget);
  });

  testWidgets("the build's plant reaches the screens", (tester) async {
    await tester.pumpWidget(
      SampleApp(catalogue: smallCatalogue, plant: Plant.rasterClip),
    );

    expect(find.byType(SlowRasterPlant), findsWidgets);
  });

  group('performance overlay', () {
    testWidgets('shows when switched on', (tester) async {
      await tester.pumpWidget(
        SampleApp(catalogue: smallCatalogue, overlay: true),
      );

      expect(find.byType(PerformanceOverlay), findsOneWidget);
    });

    testWidgets('is off by default', (tester) async {
      await tester.pumpWidget(SampleApp(catalogue: smallCatalogue));

      expect(find.byType(PerformanceOverlay), findsNothing);
    });

    test('BUTTERSCOPE_OVERLAY=on switches it on, and no value off', () {
      expect(SampleApp.overlayFromName('on'), isTrue);
      expect(SampleApp.overlayFromName(''), isFalse);
    });

    test('rejects any other value', () {
      expect(() => SampleApp.overlayFromName('true'), throwsArgumentError);
    });
  });

  test('the overrides refuse any HTTP client', () {
    HttpOverrides.runWithHttpOverrides(
      () => expect(HttpClient.new, throwsUnsupportedError),
      NoNetworkHttpOverrides(),
    );
  });
}
