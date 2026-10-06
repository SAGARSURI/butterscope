import 'dart:math';

import 'package:butterscope_sample/src/catalogue/item.dart';

/// The app's data: a fixed list of items, standing in for a backend.
///
/// Built from a seed, so every run of every test sees the same items.
class Catalogue {
  /// Holds [items], each one's title and tags lower-cased once here, so a
  /// search does not lower-case every item again on every keystroke.
  new(this.items)
    : _searchable = [
        for (final item in items)
          [
            item.title.toLowerCase(),
            for (final tag in item.tags) tag.toLowerCase(),
          ],
      ];

  /// [count] items generated from [seed].
  factory seeded({int seed = 42, int count = 5000}) {
    final random = Random(seed);
    return Catalogue([
      for (var id = 0; id < count; id++) _generate(id, random),
    ]);
  }

  /// Every item, in id order.
  final List<Item> items;

  /// Each item's title and tags in lower case, in the order of [items].
  final List<List<String>> _searchable;

  /// The items whose title or tags contain [query], ignoring case, in id
  /// order. A blank query matches nothing.
  List<Item> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return [
      for (final (index, item) in items.indexed)
        if (_searchable[index].any((text) => text.contains(needle))) item,
    ];
  }

  /// Up to [limit] other items that share [item]'s first tag.
  List<Item> related(Item item, {int limit = 10}) {
    final tag = item.tags.first;
    return items
        .where((other) => other.id != item.id && other.tags.contains(tag))
        .take(limit)
        .toList();
  }
}

// Word lists, split once at first use.
final List<String> _adjectives =
    'Amber Brisk Cedar Dusky Ember Fable Gilded Hollow Indigo Juniper '
            'Kindled Linen Marble Nimble Olive Pebble Quiet Russet Silver '
            'Tidal Umber Velvet Willow Zephyr'
        .split(' ');

final List<String> _nouns =
    'Lantern Harbour Meadow Compass Atlas Beacon Canopy Delta Ferry Glade '
            'Heron Island Kettle Ledger Mill Orchard Prism Quarry Ridge Signal '
            'Thicket Valley Wharf Yarrow'
        .split(' ');

final List<String> _tags =
    'outdoor indoor handmade vintage compact travel garden kitchen study '
            'gift seasonal classic limited repair family quiet'
        .split(' ');

const _openings = [
  'Made in small batches',
  'A steady favourite',
  'Built to last',
  'Light enough to carry',
  'Restored from an old design',
  'Shaped by hand',
];

const _closings = [
  'It suits a weekend away.',
  'It ages well with use.',
  'It packs flat when not in use.',
  'It comes with a spare part.',
  'It works in any season.',
  'It is easy to keep clean.',
];

Item _generate(int id, Random random) {
  String pick(List<String> words) => words[random.nextInt(words.length)];
  final title = '${pick(_adjectives)} ${pick(_nouns)} No. ${id + 1}';
  final first = pick(_tags);
  var second = pick(_tags);
  while (second == first) {
    second = pick(_tags);
  }
  return Item(
    id: id,
    title: title,
    tags: [first, second],
    summary:
        '${pick(_openings)}, the $title is $first and $second. '
        '${pick(_closings)}',
    rating: (10 + random.nextInt(41)) / 10,
    saves: random.nextInt(5000),
  );
}
