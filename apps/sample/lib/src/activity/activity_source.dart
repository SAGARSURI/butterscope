import 'dart:math';

/// A change to one counter: `amount` more saves for the item at `index`.
typedef Bump = ({int index, int amount});

/// A fake live feed of saves, standing in for a server push.
///
/// Every call to [events] starts the same sequence, so every visit to the
/// screen sees the same numbers.
class ActivitySource {
  const new({
    this.seed = 7,
    this.counters = 40,
    this.period = const Duration(milliseconds: 100),
  });

  final int seed;

  /// How many items have a counter.
  final int counters;

  /// How often a batch of bumps arrives.
  final Duration period;

  /// A batch of three bumps every [period].
  Stream<List<Bump>> events() {
    final random = Random(seed);
    return Stream.periodic(period, (_) {
      return [
        for (var i = 0; i < 3; i++)
          (index: random.nextInt(counters), amount: 1 + random.nextInt(5)),
      ];
    });
  }
}
