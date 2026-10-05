import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plant.fromName', () {
    test('reads each plant by its define name', () {
      expect(Plant.fromName('listener_decode'), Plant.listenerDecode);
      expect(Plant.fromName('postframe_decode'), Plant.postframeDecode);
      expect(Plant.fromName('slow_raster'), Plant.slowRaster);
      expect(Plant.fromName('backdrop_blur'), Plant.backdropBlur);
      expect(Plant.fromName('gpu_heavy'), Plant.gpuHeavy);
      expect(Plant.fromName('raster_clip'), Plant.rasterClip);
      expect(Plant.fromName('ui_busy'), Plant.uiBusy);
      expect(Plant.fromName('rebuild_all'), Plant.rebuildAll);
      expect(Plant.fromName('sync_decode'), Plant.syncDecode);
      expect(Plant.fromName('image_full_res'), Plant.imageFullRes);
      expect(Plant.fromName('gpu_blur'), Plant.gpuBlur);
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

  test('each M4 plant names its screen, and no other plant does', () {
    // tool/m4/run_tests.sh runs the plants that name a screen.
    expect(
      {
        for (final plant in Plant.values)
          if (plant.screen != null) plant.defineName: plant.screen,
      },
      {
        'raster_clip': 'Feed',
        'ui_busy': 'Search',
        'rebuild_all': 'Activity',
        'sync_decode': 'Inbox',
        'image_full_res': 'Gallery',
        'gpu_blur': 'Detail',
      },
    );
  });
}
