import 'package:butterscope_sample/src/feed/feed_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/raster_plants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

void main() {
  testWidgets('shows a card for each item', (tester) async {
    await tester.pumpWidget(inApp(FeedScreen(catalogue: smallCatalogue)));

    expect(find.byType(ItemCard), findsNWidgets(4));
    expect(find.text('Quiet Harbour No. 2'), findsOneWidget);
    expect(find.text('indoor · gift'), findsOneWidget);
  });

  testWidgets('cards grow to fit large text', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: inApp(FeedScreen(catalogue: smallCatalogue)),
      ),
    );

    // An overflowing card reports a layout error, which fails the test.
    expect(tester.takeException(), isNull);
    expect(find.text('Amber Lantern No. 1'), findsOneWidget);
  });

  testWidgets('a screen reader hears each title, not the picture', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(inApp(FeedScreen(catalogue: smallCatalogue)));

    // The card reads as one label. The picture shows the title's initial,
    // "Q" for Quiet Harbour, which must not be read before the title.
    final card = tester.getSemantics(
      find.descendant(
        of: find.byKey(const Key('item-card-1')),
        matching: find.byType(InkWell),
      ),
    );
    expect(card.label, startsWith('Quiet Harbour No. 2\n'));
    semantics.dispose();
  });

  testWidgets('tapping a card opens its detail page', (tester) async {
    await tester.pumpWidget(inApp(FeedScreen(catalogue: smallCatalogue)));

    await tester.tap(find.byKey(const Key('item-card-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-title')), findsOneWidget);
    expect(find.text('Summary of Cedar Lantern No. 3.'), findsOneWidget);
  });

  group('raster_clip', () {
    testWidgets('wraps every card in save layers', (tester) async {
      await tester.pumpWidget(
        inApp(FeedScreen(catalogue: smallCatalogue), plant: Plant.rasterClip),
      );

      expect(find.byType(SlowRasterPlant), findsNWidgets(4));
      expect(find.text('Quiet Harbour No. 2'), findsOneWidget);
    });

    testWidgets('leaves every card clearly visible', (tester) async {
      await tester.pumpWidget(
        inApp(FeedScreen(catalogue: smallCatalogue), plant: Plant.rasterClip),
      );

      final layers = tester.widgetList<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('item-card-0')),
          matching: find.byType(Opacity),
        ),
      );
      final shown = layers.fold<double>(
        1,
        (product, layer) => product * layer.opacity,
      );
      // Tests run with the Android depth, 60. Each layer would get
      // 0.9^(1/60) = 0.99825, over the 254/255 = 0.99608 cap, so each gets
      // 254/255 and the stack shows at (254/255)^60 = e^(60 x -0.0039293)
      // = 0.790. A card at three quarters or more stays clearly visible;
      // past 73 layers it would not, since (254/255)^73 = 0.751.
      expect(shown, closeTo(0.790, 0.001));
      expect(shown, greaterThanOrEqualTo(0.75));
    });

    testWidgets('the clean build has none', (tester) async {
      await tester.pumpWidget(inApp(FeedScreen(catalogue: smallCatalogue)));

      expect(find.byType(SlowRasterPlant), findsNothing);
    });
  });
}
