import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/plant_costs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const layers = PlantCost<int>(Plant.rasterClip, android: 1, ios: 2);
  const sigma = PlantCost<double>(Plant.gpuBlur, android: 10, ios: 20);

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('an Android build gets the Android value', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(layers.value, 1);
  });

  test('an iOS build gets the iOS value', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(layers.value, 2);
  });

  group('BUTTERSCOPE_COST', () {
    test("replaces the knob of the build's plant", () {
      expect(layers.resolve(Plant.rasterClip, '7'), 7);
      expect(sigma.resolve(Plant.gpuBlur, '12.5'), 12.5);
    });

    test('reads a whole number for a decimal knob', () {
      expect(sigma.resolve(Plant.gpuBlur, '30'), 30.0);
    });

    test("leaves other plants' knobs alone", () {
      expect(layers.resolve(Plant.gpuBlur, '7'), 1);
      expect(layers.resolve(Plant.none, '7'), 1);
    });

    test('unset, gives the platform value', () {
      expect(layers.resolve(Plant.rasterClip, ''), 1);
    });

    test('rejects a value that is not a number of the knob type', () {
      expect(
        () => layers.resolve(Plant.rasterClip, '7.5'),
        throwsFormatException,
      );
      expect(() => sigma.resolve(Plant.gpuBlur, 'big'), throwsFormatException);
    });

    test('rejects a value that is not finite and above 0', () {
      for (final cost in ['0', '-2', 'Infinity', 'NaN']) {
        expect(
          () => sigma.resolve(Plant.gpuBlur, cost),
          throwsArgumentError,
          reason: cost,
        );
      }
      expect(() => layers.resolve(Plant.rasterClip, '0'), throwsArgumentError);
    });
  });
}
