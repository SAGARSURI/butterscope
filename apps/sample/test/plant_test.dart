import 'package:butterscope_sample/src/plant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plant.fromName', () {
    test('reads each plant by its define name', () {
      expect(Plant.fromName('listener_decode'), Plant.listenerDecode);
      expect(Plant.fromName('postframe_decode'), Plant.postframeDecode);
      expect(Plant.fromName('slow_raster'), Plant.slowRaster);
      expect(Plant.fromName('backdrop_blur'), Plant.backdropBlur);
      expect(Plant.fromName('gpu_heavy'), Plant.gpuHeavy);
    });

    test('reads an empty name as no plant', () {
      expect(Plant.fromName(''), Plant.none);
    });

    test('rejects an unknown name', () {
      expect(() => Plant.fromName('slow-raster'), throwsArgumentError);
    });
  });

  test('a build without the define has no plant', () {
    expect(Plant.fromEnvironment(), Plant.none);
  });
}
