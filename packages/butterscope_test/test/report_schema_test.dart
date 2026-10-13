// The phone's report against what butterscope_report freezes for schema
// v1. The attach tests check whole reports; these check the lists that
// v1 freezes against the code that writes them.

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_report/butterscope_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the guards are the ones v1 freezes', () {
    expect({for (final guard in Guard.values) guard.name}, guardNames);
  });

  test("a frame row's numbers are in v1's field order", () {
    final report = RunReport(
      const RecordedWindow(
        startFrameNumber: 0,
        endFrameNumber: 1,
        samples: [
          FrameSample(
            vsyncStartMicros: 2,
            buildMicros: 4,
            rasterMicros: 5,
            vsyncOverheadMicros: 3,
            frameNumber: 1,
            totalSpanMicros: 6,
            rasterCache: RasterCacheUse(
              layerCount: 7,
              layerBytes: 8,
              pictureCount: 9,
              pictureBytes: 10,
            ),
          ),
        ],
        refreshRateReads: [],
        flushTimedOut: false,
        flushMicros: 0,
        callbackMicros: 0,
      ),
      const [],
      runId: 1,
      identity: const RunIdentity(
        platform: 'android',
        device: null,
        buildMode: 'profile',
        flutterVersion: null,
        engineRevision: null,
        appCommit: 'unknown',
        textScale: 1,
        locale: 'en-GB',
      ),
    );

    expect(Map.fromIterables(frameFields, report.frameRows.single), {
      'frame': 1,
      'vsyncStartUs': 2,
      'vsyncOverheadUs': 3,
      'buildUs': 4,
      'rasterUs': 5,
      'totalSpanUs': 6,
      'cacheLayers': 7,
      'cacheLayerBytes': 8,
      'cachePictures': 9,
      'cachePictureBytes': 10,
    });
  });
}
