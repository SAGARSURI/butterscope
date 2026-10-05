import 'package:butterscope_sample/src/plants/plant_costs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cost = PlantCost<int>(android: 1, ios: 2);

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('an Android build gets the Android value', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(cost.value, 1);
  });

  test('an iOS build gets the iOS value', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(cost.value, 2);
  });
}
