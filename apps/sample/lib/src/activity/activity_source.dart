import 'dart:math';

/// A change to one counter: `amount` more saves for the item at `index`.
typedef Bump = ({int index, int amount});

/// A fake live feed of saves, standing in for a server push.
///
/// Every call to [events] starts the same sequence, so every visit to the
/// screen sees the same numbers.
class ActivitySource {
  const new({this.seed = 7, this.period = const Duration(milliseconds: 100)});

  final int seed;

  /// How often a batch of bumps arrives.
  final Duration period;

  /// A batch of three bumps every [period], each to one of the first
  /// [counters] items.
  ///
  /// Throws an [ArgumentError] when [counters] is below 1: there would be
  /// no item to bump.
  Stream<List<Bump>> events(int counters) {
    if (counters < 1) {
      throw ArgumentError.value(counters, 'counters', 'must be at least 1');
    }
    final random = Random(seed);
    return Stream.periodic(period, (_) {
      return [
        for (var i = 0; i < 3; i++)
          (index: random.nextInt(counters), amount: 1 + random.nextInt(5)),
      ];
    });
  }
}
