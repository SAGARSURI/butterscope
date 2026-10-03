import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nearestRankPercentile', () {
    // The standard worked example for the nearest-rank method.
    const values = [15, 20, 35, 40, 50];

    test('returns the value at rank ceil(p × n / 100)', () {
      expect(nearestRankPercentile(values, 5), 15);
      expect(nearestRankPercentile(values, 30), 20);
      expect(nearestRankPercentile(values, 40), 20);
      expect(nearestRankPercentile(values, 50), 35);
      expect(nearestRankPercentile(values, 100), 50);
    });

    test('sorts the values first', () {
      expect(nearestRankPercentile([50, 15, 40, 20, 35], 50), 35);
    });

    test('of one value is that value', () {
      expect(nearestRankPercentile([7.5], 1), 7.5);
      expect(nearestRankPercentile([7.5], 99), 7.5);
    });

    test('p90 and p99 of ten values are the 9th and the 10th', () {
      final tens = [for (var i = 1; i <= 10; i++) i];
      expect(nearestRankPercentile(tens, 90), 9);
      expect(nearestRankPercentile(tens, 99), 10);
    });

    test('rejects an empty list and a percent outside 1 to 100', () {
      expect(() => nearestRankPercentile(<int>[], 50), throwsArgumentError);
      expect(() => nearestRankPercentile(values, 0), throwsRangeError);
      expect(() => nearestRankPercentile(values, 101), throwsRangeError);
    });
  });
}
