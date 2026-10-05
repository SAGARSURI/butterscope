import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

List<int> ids(Iterable<Item> items) => [for (final item in items) item.id];

void main() {
  group('Catalogue.search', () {
    test('matches a title fragment, ignoring case, in id order', () {
      // "lantern" is in the titles of items 0 and 2.
      expect(ids(smallCatalogue.search('LANTERN')), [0, 2]);
    });

    test('matches a tag', () {
      // "outdoor" is a tag of items 0, 2 and 3; no title contains it.
      expect(ids(smallCatalogue.search('outdoor')), [0, 2, 3]);
    });

    test('ignores surrounding spaces', () {
      expect(ids(smallCatalogue.search('  gift ')), [1]);
    });

    test('a blank query matches nothing', () {
      expect(smallCatalogue.search('   '), isEmpty);
    });
  });

  group('Catalogue.related', () {
    test('lists other items sharing the first tag', () {
      // Item 0's first tag is "outdoor"; items 2 and 3 have it too.
      expect(ids(smallCatalogue.related(smallCatalogue.items[0])), [2, 3]);
    });

    test('stops at the limit', () {
      final related = smallCatalogue.related(smallCatalogue.items[0], limit: 1);
      expect(ids(related), [2]);
    });
  });

  group('Catalogue.seeded', () {
    test('the same seed gives the same items', () {
      final first = Catalogue.seeded(count: 50);
      final second = Catalogue.seeded(count: 50);
      expect(
        [for (final item in first.items) item.summary],
        [for (final item in second.items) item.summary],
      );
    });

    test('has 5,000 items by default, each id its position', () {
      final items = Catalogue.seeded().items;
      expect(items, hasLength(5000));
      expect(ids(items), List.generate(5000, (i) => i));
    });

    test('ratings run from 1.0 to 5.0 and tags differ', () {
      for (final item in Catalogue.seeded(count: 500).items) {
        expect(item.rating, inInclusiveRange(1.0, 5.0));
        expect(item.tags.toSet(), hasLength(2));
      }
    });
  });
}
