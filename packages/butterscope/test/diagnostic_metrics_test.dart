import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosticMetrics', () {
    // Three frames, times in µs.
    const frames = [
      FrameSample(
        vsyncStartMicros: 0,
        vsyncOverheadMicros: 500,
        buildMicros: 3000,
        rasterMicros: 4000,
        totalSpanMicros: 8000,
        rasterCache: RasterCacheUse(
          layerCount: 2,
          layerBytes: 100,
          pictureCount: 1,
          pictureBytes: 50,
        ),
      ),
      FrameSample(
        vsyncStartMicros: 8333,
        // A negative wait counts as none in UI time.
        vsyncOverheadMicros: -100,
        buildMicros: 5000,
        rasterMicros: 2000,
        totalSpanMicros: 9000,
        rasterCache: RasterCacheUse(
          layerCount: 3,
          layerBytes: 80,
          pictureCount: 4,
          pictureBytes: 10,
        ),
      ),
      FrameSample(
        vsyncStartMicros: 16667,
        vsyncOverheadMicros: 1500,
        buildMicros: 1000,
        rasterMicros: 6000,
        totalSpanMicros: 12000,
        rasterCache: RasterCacheUse(
          layerCount: 1,
          layerBytes: 300,
          pictureCount: 0,
          pictureBytes: 0,
        ),
      ),
    ];

    test('averages UI, build and raster time in ms', () {
      final metrics = DiagnosticMetrics.of(frames);

      // UI: 500 + 3000, 0 + 5000, 1500 + 1000 = 11000 µs over 3 frames.
      expect(metrics.averageUiMillis, closeTo(11 / 3, 1e-9));
      // Build: (3000 + 5000 + 1000) / 3 = 3000 µs.
      expect(metrics.averageBuildMillis, 3);
      // Raster: (4000 + 2000 + 6000) / 3 = 4000 µs.
      expect(metrics.averageRasterMillis, 4);
    });

    test('takes nearest-rank p90 and p99 of the wait and the latency', () {
      // Waits of 100, 200, ... 2000 µs and latencies of 1, 2, ... 20 ms.
      final twenty = [
        for (var i = 1; i <= 20; i++)
          FrameSample(
            vsyncStartMicros: i * 8333,
            vsyncOverheadMicros: i * 100,
            buildMicros: 1000,
            rasterMicros: 1000,
            totalSpanMicros: i * 1000,
          ),
      ];

      final metrics = DiagnosticMetrics.of(twenty);

      // p90 is rank ⌈90 × 20 ÷ 100⌉ = 18; p99 is rank ⌈99 × 20 ÷ 100⌉ = 20.
      expect(metrics.vsyncOverheadP90Millis, 1.8);
      expect(metrics.vsyncOverheadP99Millis, 2);
      expect(metrics.totalSpanP90Millis, 18);
      expect(metrics.totalSpanP99Millis, 20);
    });

    test('keeps the largest raster cache figure of each kind', () {
      final peak = DiagnosticMetrics.of(frames).peakRasterCache!;

      // Each peak comes from a different frame: 3 layers from the second,
      // 300 layer bytes from the third, 4 pictures and 50 picture bytes
      // from the second and first.
      expect(peak.layerCount, 3);
      expect(peak.layerBytes, 300);
      expect(peak.pictureCount, 4);
      expect(peak.pictureBytes, 50);
    });

    test('has no values for an empty window', () {
      final metrics = DiagnosticMetrics.of(const []);

      expect(metrics.averageUiMillis, isNull);
      expect(metrics.averageBuildMillis, isNull);
      expect(metrics.averageRasterMillis, isNull);
      expect(metrics.vsyncOverheadP90Millis, isNull);
      expect(metrics.vsyncOverheadP99Millis, isNull);
      expect(metrics.totalSpanP90Millis, isNull);
      expect(metrics.totalSpanP99Millis, isNull);
      expect(metrics.peakRasterCache, isNull);
    });
  });
}
