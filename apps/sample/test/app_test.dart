import 'dart:io';

import 'package:butterscope_sample/main.dart';
import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/feed/feed_screen.dart';
import 'package:butterscope_sample/src/no_network.dart';
import 'package:butterscope_sample/src/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

void main() {
  testWidgets('opens on the feed and switches to search', (tester) async {
    await tester.pumpWidget(SampleApp(catalogue: smallCatalogue));
    expect(find.byType(FeedScreen), findsOneWidget);

    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
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

  test('the overrides refuse any HTTP client', () {
    HttpOverrides.runWithHttpOverrides(
      () => expect(HttpClient.new, throwsUnsupportedError),
      NoNetworkHttpOverrides(),
    );
  });
}
