/// The [percent]th percentile of [values], by the nearest-rank method.
///
/// Sorts the values in ascending order and returns the one at rank
/// `⌈percent × n ÷ 100⌉`, counting from 1. The rank is computed in integers
/// and the result is always one of the values, so it never depends on
/// rounding or interpolation. The 100th percentile is the largest value.
///
/// Throws an [ArgumentError] when [values] is empty or [percent] is not
/// between 1 and 100.
T nearestRankPercentile<T extends num>(Iterable<T> values, int percent) {
  return nearestRankOfSorted(values.toList()..sort(), percent);
}

/// The [percent]th percentile of [sorted], by the nearest-rank method.
///
/// Same as [nearestRankPercentile], for values already sorted in ascending
/// order, so a caller can sort once and read several percentiles.
///
/// Throws an [ArgumentError] when [sorted] is empty or [percent] is not
/// between 1 and 100.
T nearestRankOfSorted<T extends num>(List<T> sorted, int percent) {
  if (percent < 1 || percent > 100) {
    throw RangeError.range(percent, 1, 100, 'percent');
  }
  if (sorted.isEmpty) {
    throw ArgumentError.value(sorted, 'sorted', 'must not be empty');
  }
  final rank = (percent * sorted.length + 99) ~/ 100;
  return sorted[rank - 1];
}
