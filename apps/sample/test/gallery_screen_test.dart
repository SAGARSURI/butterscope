import 'package:butterscope_sample/src/gallery/gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

/// The width a photo is decoded at, in physical pixels.
int? decodedWidth(WidgetTester tester, int index) {
  final image = tester.widget<Image>(find.byKey(Key('photo-$index')));
  return (image.image as ResizeImage).width;
}

void main() {
  testWidgets('decodes each grid photo at its cell width', (tester) async {
    await tester.pumpWidget(inApp(const GalleryScreen()));

    // The test screen is 800 logical pixels wide at 3x: three columns of
    // 800 / 3 logical pixels are 800 physical pixels each.
    expect(decodedWidth(tester, 0), 800);
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
}
