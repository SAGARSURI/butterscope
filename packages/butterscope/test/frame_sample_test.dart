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
}
