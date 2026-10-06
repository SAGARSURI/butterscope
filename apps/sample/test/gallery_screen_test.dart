import 'dart:typed_data';

import 'package:butterscope_sample/src/gallery/gallery_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/screen_plants.dart';
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

  test('averages pixels, ignoring alpha', () {
    final rgba = ByteData.sublistView(
      Uint8List.fromList([10, 20, 30, 255, 30, 40, 51, 0]),
    );

    // (10 + 30) / 2 = 20, (20 + 40) / 2 = 30, (30 + 51) / 2 = 40.5, which
    // rounds down to 40.
    expect(averageColour(rgba), const Color.fromARGB(255, 20, 30, 40));
  });

  testWidgets('photo_tint frames each cell in a colour read from its photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      inApp(const GalleryScreen(), plant: Plant.photoTint),
    );
    Color tint(int index) => tester
        .widget<ColoredBox>(
          find.ancestor(
            of: find.byKey(Key('photo-$index')),
            matching: find.byKey(const Key('photo-tint')),
          ),
        )
        .color;

    // Decoding the copies and reading their pixels runs outside the test's
    // fake clock.
    for (var tries = 0; tries < 50; tries++) {
      if (tint(0).a == 1 && tint(1).a == 1) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    // Cells 0 and 1 show different photos, so their frames differ.
    expect(tint(0).a, 1);
    expect(tint(1).a, 1);
    expect(tint(0), isNot(tint(1)));
  });
}
