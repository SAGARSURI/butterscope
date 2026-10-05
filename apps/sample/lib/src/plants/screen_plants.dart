import 'dart:math';

import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:flutter/material.dart';

/// The search the `ui_busy` plant runs: the same results as
/// [Catalogue.search], best match first.
///
/// The mistake is scoring every item in the catalogue on the UI thread, on
/// every keystroke. An item's score is the smallest edit distance from the
/// query to any of the first [words] words of its title, tags and summary;
/// items with the same score stay in id order.
List<Item> fuzzySearch(
  Catalogue catalogue,
  String query, {
  required int words,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final scores = <int>[];
  for (final item in catalogue.items) {
    final distances = '${item.title} ${item.tags.join(' ')} ${item.summary}'
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((word) => word.isNotEmpty)
        .take(words)
        .map((word) => _editDistance(needle, word))
        .toList();
    // An item with no words is as far as an empty word: the query's length.
    scores.add(distances.isEmpty ? needle.length : distances.reduce(min));
  }
  // An item's id is its position in the catalogue.
  return catalogue.search(needle)..sort((a, b) {
    final byScore = scores[a.id].compareTo(scores[b.id]);
    return byScore != 0 ? byScore : a.id.compareTo(b.id);
  });
}

/// The fewest single-letter insertions, deletions and substitutions that
/// turn [a] into [b] (Levenshtein distance), kept two rows at a time.
int _editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (j) => j);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final substitution = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = min(
        min(current[j - 1], previous[j]) + 1,
        previous[j - 1] + substitution,
      );
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

/// A progress bar drawn as [segments] separate boxes, for `rebuild_all`:
/// every box is built and laid out again whenever the bar is.
class SegmentedBar extends StatelessWidget {
  const new({required this.value, required this.segments, super.key});

  /// From 0 to 1: the share of segments filled.
  final double value;

  final int segments;

  @override
  Widget build(BuildContext context) {
    final filled = (value * segments).round();
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 4,
      child: Row(
        children: [
          for (var i = 0; i < segments; i++)
            Expanded(
              child: ColoredBox(
                color: i < filled
                    ? colors.primary
                    : colors.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }
}
