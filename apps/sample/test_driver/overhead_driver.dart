// Host side of integration_test/m2_overhead_test.dart: summarises each
// traced window's frame build and raster times, prints them, and saves them
// to build/bscope_overhead/<arm>-<time>.json. BSCOPE_ARM names the arm, `on`
// or `off`, to match the test's BUTTERSCOPE_RECORDER.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Map<String, Object> summarise(Map<String, dynamic> trace) {
  final summary = TimelineSummary.summarize(Timeline.fromJson(trace));
  return {
    'frames': summary.countFrames(),
    'buildP50Millis': summary.computePercentileFrameBuildTimeMillis(50),
    'buildP99Millis': summary.computePercentileFrameBuildTimeMillis(99),
    'buildWorstMillis': summary.computeWorstFrameBuildTimeMillis(),
    'rasterP50Millis': summary.computePercentileFrameRasterizerTimeMillis(50),
    'rasterP99Millis': summary.computePercentileFrameRasterizerTimeMillis(99),
    'rasterWorstMillis': summary.computeWorstFrameRasterizerTimeMillis(),
  };
}

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      final arm = Platform.environment['BSCOPE_ARM'] ?? 'unknown';
      final windows = {
        for (final MapEntry(:key, :value) in (data ?? const {}).entries)
          key: summarise(value as Map<String, dynamic>),
      };
      for (final MapEntry(:key, :value) in windows.entries) {
        stdout.writeln('BSCOPE overhead arm=$arm window=$key $value');
      }
      final time = DateTime.now().toUtc().toIso8601String();
      final file = File('build/bscope_overhead/$arm-$time.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'arm': arm, ...windows}));
    },
  );
}
