import 'package:butterscope_sample/src/detail/detail_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/raster_plants.dart';
import 'package:butterscope_sample/src/widgets/item_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

Widget detailOf(int id, {Plant plant = Plant.none}) {
  return PlantScope(
    plant: plant,
    child: MaterialApp(
      home: DetailScreen(
        catalogue: smallCatalogue,
        item: smallCatalogue.items[id],
      ),
    ),
  );
}

void main() {
  testWidgets('shows the item and its facts', (tester) async {
    await tester.pumpWidget(detailOf(1));

    expect(find.text('Quiet Harbour No. 2'), findsOneWidget);
    expect(find.text('Summary of Quiet Harbour No. 2.'), findsOneWidget);
    expect(find.text('Rated 4.5 of 5'), findsOneWidget);
    expect(find.text('Saved by 7 people'), findsOneWidget);
  });

  testWidgets('lists related items and opens one', (tester) async {
    await tester.pumpWidget(detailOf(0));

    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-end')),
      200,
      scrollable: find.byType(Scrollable),
    );

    // Items 2 and 3 share item 0's first tag, "outdoor".
    expect(find.byType(ItemTile), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('item-tile-3')));
    await tester.pumpAndSettle();

    expect(find.text('Summary of Silver Meadow No. 4.'), findsOneWidget);
  });

  group('gpu_blur', () {
    testWidgets('blurs the header picture', (tester) async {
      await tester.pumpWidget(detailOf(1, plant: Plant.gpuBlur));

      expect(find.byType(BackdropBlurPlant), findsOneWidget);
      expect(find.text('Quiet Harbour No. 2'), findsOneWidget);
    });

    testWidgets('the clean build has no blur plant', (tester) async {
      await tester.pumpWidget(detailOf(1));

      expect(find.byType(BackdropBlurPlant), findsNothing);
    });
  });
}
