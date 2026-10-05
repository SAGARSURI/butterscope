import 'package:butterscope_sample/src/gallery/gallery_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

/// The width a photo is decoded at, in physical pixels.
int? decodedWidth(WidgetTester tester, int index) {
  final image = tester.widget<Image>(find.byKey(Key('photo-$index')));
  return (image.image as ResizeImage).width;
}

void main() {
  testWidgets('decodes each grid photo at the width it is drawn', (
    tester,
  ) async {
    await tester.pumpWidget(inApp(const GalleryScreen()));

    // The test screen is 800 logical pixels wide at 3x, so a column is 800
    // physical pixels. A 4:3 photo covering a square cell is drawn 4/3 as
    // wide: 800 x 4 / 3 = 1066.7, rounded up to 1067.
    expect(decodedWidth(tester, 0), 1067);
  });

  testWidgets('opens a photo and swipes to the next', (tester) async {
    await tester.pumpWidget(inApp(const GalleryScreen()));

    await tester.tap(find.byKey(const Key('photo-4')));
    await tester.pumpAndSettle();
    expect(find.text('5 / 60'), findsOneWidget);
    // Full width: 800 logical pixels at 3x.
    expect(decodedWidth(tester, 4), 2400);

    await tester.fling(
      find.byKey(const Key('photo-viewer')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('6 / 60'), findsOneWidget);
  });

  testWidgets('image_full_res decodes every grid photo at full size', (
    tester,
  ) async {
    await tester.pumpWidget(
      inApp(const GalleryScreen(), plant: Plant.imageFullRes),
    );

    // The photos are 4032 x 3024, and the cell needs 1067.
    expect(decodedWidth(tester, 0), 4032);
  });
}
