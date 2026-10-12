import 'dart:convert';

import 'package:butterscope_report/butterscope_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small report that matches schema v1: one span with one janky frame.
const String _validJson = '''
{
  "schema": 1,
  "runId": 42,
  "identity": {
    "platform": "android",
    "model": "samsung SM-S921B",
    "osVersion": "Android 16 (API 36)",
    "buildMode": "profile",
    "thermalAtStart": "none",
    "flutterVersion": "3.47.6",
    "engineRevision": "abc",
    "appCommit": "unknown",
    "textScale": 1.0,
    "locale": "en-GB"
  },
  "valid": true,
  "reasons": [],
  "frameCount": 12,
  "flushTimedOut": false,
  "flushMicros": 0,
  "callbackMicros": 0,
  "rateReads": [[0, 100, 120.0], [6, null, null]],
  "parts": [
    {
      "kind": "span",
      "name": "feed scroll",
      "startFrame": 0,
      "endFrame": 12,
      "startMicros": 0,
      "endMicros": 100000,
      "declaredHz": 120.0,
      "declaredHzAtEnd": 120.0,
      "frames": 12,
      "metrics": {
        "observedHz": 120.0,
        "rateSlicesJudged": 1,
        "rateMismatches": [],
        "hitchRatio": 0.4,
        "hitchMs": 3.7,
        "renderingMs": 100.0,
        "missedVsyncs": 0,
        "missedVsyncMs": 0.0,
        "janky": 1,
        "jankyRate": 0.083,
        "jankyRateUi": 0.083,
        "jankyRateRaster": 0.0,
        "jankyRateBoth": 0.0,
        "severe": 0,
        "stalls": 0,
        "uiP90B": 0.3,
        "uiP99B": 1.4,
        "worstUiB": 1.44,
        "rasterP90B": 0.2,
        "rasterP99B": 0.2,
        "worstRasterB": null
      },
      "diagnostics": {
        "avgUiMs": 2.8,
        "avgBuildMs": 2.8,
        "avgRasterMs": 2.0,
        "vsyncOverheadP90Ms": 0.0,
        "vsyncOverheadP99Ms": 0.0,
        "totalSpanP90Ms": null,
        "totalSpanP99Ms": null
      },
      "valid": true,
      "reasons": [],
      "semantics": [false, false]
    }
  ],
  "issues": [[0, 6, 41.665, "ui", 0.44, "janky"]],
  "activity": [["input", 2, 16666, 3, 24999]],
  "pages": [[1, 8333, "/", false]]
}
''';

void main() {
  Map<String, Object?> valid() {
    return jsonDecode(_validJson) as Map<String, Object?>;
  }

  Map<String, Object?> firstPart(Map<String, Object?> report) {
    return (report['parts']! as List<Object?>).first! as Map<String, Object?>;
  }

  test('accepts a report that matches v1', () {
    expect(checkReport(valid()), isEmpty);
  });

  test('names a missing field by its path', () {
    final report = valid();
    (firstPart(report)['metrics']! as Map<String, Object?>).remove('janky');

    expect(checkReport(report), [
      const SchemaProblem('parts[0].metrics.janky', 'missing'),
    ]);
  });

  test('names a field v1 does not have', () {
    final report = valid()..['frames'] = <Object?>[];

    expect(checkReport(report), [
      const SchemaProblem('frames', 'not in schema v1'),
    ]);
  });

  test('names a value of the wrong type', () {
    final report = valid()..['frameCount'] = '12';

    expect(checkReport(report), [
      const SchemaProblem('frameCount', 'expected an integer, got 12'),
    ]);
  });

  test('refuses a guard v1 does not name', () {
    final report = valid()
      ..['reasons'] = [
        ['charging', 'run start'],
      ];

    expect(checkReport(report).single.path, 'reasons[0][0]');
  });

  test('refuses an issue that names no part', () {
    // The report has one part, index 0, so index 1 names none.
    final report = valid();
    ((report['issues']! as List<Object?>).single! as List<Object?>)[0] = 1;

    expect(checkReport(report), [
      const SchemaProblem('issues[0][0]', 'names no part'),
    ]);
  });

  test('gives one problem for another schema version', () {
    expect(checkReport({'schema': 0, 'frames': 34}), [
      const SchemaProblem('schema', 'expected 1, got 0'),
    ]);
  });

  test('checks a version that is not an integer like any field', () {
    final report = valid()..['schema'] = '1';

    expect(checkReport(report), [
      const SchemaProblem('schema', 'expected an integer, got 1'),
    ]);
  });

  test('refuses a report that is not an object', () {
    expect(checkReport([1]).single.message, 'expected an object, got [1]');
  });

  test('wants one integer per frame field in each frame row', () {
    final whole = [for (var i = 0; i < frameFields.length; i++) i];

    expect(checkFrames([whole]), isEmpty);
    expect(
      checkFrames([whole, whole.take(9).toList()]).single.path,
      'frames[1]',
    );
    expect(
      checkFrames([
        [...whole.take(9), 1.5],
      ]).single.path,
      'frames[0][9]',
    );
  });
}
