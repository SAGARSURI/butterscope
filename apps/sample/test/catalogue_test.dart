import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

// The screens' tests cover what a user sees of the catalogue. These pin
// the one thing no screen shows: every run gets the same data, which
// comparing a run with its baseline depends on (DESIGN section 6, item 7).
void main() {
  test('the same seed gives the same items', () {
    final first = Catalogue.seeded(count: 50);
    final second = Catalogue.seeded(count: 50);
    expect(
      [for (final item in first.items) item.summary],
      [for (final item in second.items) item.summary],
    );
  });

  test('the app catalogue has 5,000 items', () {
    expect(Catalogue.seeded().items, hasLength(5000));
  });
}
