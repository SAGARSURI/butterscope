import 'dart:ui';

import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FrameSample.fromTiming keeps the times Butterscope measures', () {
    final sample = FrameSample.fromTiming(
      FrameTiming(
        vsyncStart: 1000,
        buildStart: 1500,
        buildFinish: 9500,
        rasterStart: 9600,
        rasterFinish: 15600,
        rasterFinishWallTime: 15600,
        frameNumber: 7,
      ),
    );

    expect(sample.vsyncStartMicros, 1000);
    expect(sample.vsyncOverheadMicros, 500);
    expect(sample.buildMicros, 8000);
    expect(sample.rasterMicros, 6000);
    expect(sample.frameNumber, 7);
  });

  test('FrameSample.fromTiming keeps the latency and raster cache', () {
    final sample = FrameSample.fromTiming(
      FrameTiming(
        vsyncStart: 1000,
        buildStart: 1500,
        buildFinish: 9500,
        rasterStart: 9600,
        rasterFinish: 15600,
        rasterFinishWallTime: 15600,
        layerCacheCount: 3,
        layerCacheBytes: 4096,
        pictureCacheCount: 2,
        pictureCacheBytes: 512,
      ),
    );

    // Vsync at 1000 µs to raster finish at 15600 µs.
    expect(sample.totalSpanMicros, 14600);
    expect(sample.rasterCache.layerCount, 3);
    expect(sample.rasterCache.layerBytes, 4096);
    expect(sample.rasterCache.pictureCount, 2);
    expect(sample.rasterCache.pictureBytes, 512);
  });
}
