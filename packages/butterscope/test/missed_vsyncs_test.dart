import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smooth frames whose vsyncs are [gaps] microseconds apart.
List<FrameSample> framesWithGaps(List<int> gaps) {
  final vsyncs = [0];
  for (final gap in gaps) {
    vsyncs.add(vsyncs.last + gap);
  }
  return [
    for (final vsync in vsyncs)
      FrameSample(
        vsyncStartMicros: vsync,
        buildMicros: 2000,
        rasterMicros: 1000,
      ),
  ];
}

void main() {
  group('countMissedVsyncs', () {
    final at120 = FrameBudget(120);

    test('is 0 when every vsync has a frame, jitter included', () {
      final gaps = [8333, 8290, 8380, 8333, 8350, 8310];
      expect(countMissedVsyncs(framesWithGaps(gaps), at120), 0);
    });

    test('counts the vsyncs inside a gap of whole intervals', () {
      // 25 ms at 120 Hz is three intervals: two vsyncs had no frame.
      final frames = framesWithGaps([8333, 25000, 8333]);
      expect(countMissedVsyncs(frames, at120), 2);
    });

    test('rounds a gap to the nearest whole interval', () {
      // 1.4 intervals rounds to 1 (none missed); 1.6 rounds to 2 (one).
      expect(countMissedVsyncs(framesWithGaps([11666]), at120), 0);
      expect(countMissedVsyncs(framesWithGaps([13333]), at120), 1);
    });

    test("leaves out the vsyncs a frame's own UI time explains", () {
      // A 30 ms build at 120 Hz spans four intervals; its lateness is its
      // overrun, so the four-interval gap after it adds nothing. Two more
      // intervals on top are counted.
      FrameSample frame(int vsync, int build) {
        return FrameSample(
          vsyncStartMicros: vsync,
          buildMicros: build,
          rasterMicros: 1000,
        );
      }

      final explained = [frame(0, 30000), frame(33333, 2000)];
      expect(countMissedVsyncs(explained, at120), 0);
      final beyond = [frame(0, 30000), frame(50000, 2000)];
      expect(countMissedVsyncs(beyond, at120), 2);
    });

    test('counts a long freeze in full', () {
      // 300 ms at 60 Hz is 18 intervals: 17 vsyncs had no frame.
      final frames = framesWithGaps([300000]);
      expect(countMissedVsyncs(frames, FrameBudget(60)), 17);
    });

    test('ignores gaps of zero or less', () {
      final frames = framesWithGaps([0, -10, 8333]);
      expect(countMissedVsyncs(frames, at120), 0);
    });

    test('is 0 with fewer than two frames', () {
      expect(countMissedVsyncs(const [], at120), 0);
      expect(countMissedVsyncs(framesWithGaps([]), at120), 0);
    });
  });
}
