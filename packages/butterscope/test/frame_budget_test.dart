import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrameBudget', () {
    test('is 1000 / refresh rate milliseconds', () {
      expect(FrameBudget(60).millis, closeTo(16.667, 0.001));
      expect(FrameBudget(90).millis, closeTo(11.111, 0.001));
      expect(FrameBudget(120).millis, closeTo(8.333, 0.001));
      expect(FrameBudget(144).millis, closeTo(6.944, 0.001));
    });

    test('is in microseconds for FrameTiming', () {
      expect(FrameBudget(125).micros, 8000);
    });

    test('rejects a rate that is not positive and finite', () {
      for (final rate in <double>[0, -60, double.nan, double.infinity]) {
        expect(FrameBudget.isValidRefreshRate(rate), isFalse);
        expect(() => FrameBudget(rate), throwsArgumentError);
      }
    });

    test('accepts any positive, finite rate', () {
      for (final rate in <double>[59.94, 60, 90, 120, 144]) {
        expect(FrameBudget.isValidRefreshRate(rate), isTrue);
      }
    });
  });
}
