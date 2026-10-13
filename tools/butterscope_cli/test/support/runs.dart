// Lines of runs as the phone prints them, for the collect tests.

import 'package:butterscope_report/butterscope_report.dart';

/// A report that matches schema v1, of [frameCount] frames, with no parts.
Map<String, Object?> reportOf(int runId, int frameCount) {
  return {
    'schema': 1,
    'runId': runId,
    'identity': {
      'platform': 'android',
      'model': 'samsung SM-S921B',
      'osVersion': 'Android 16 (API 36)',
      'buildMode': 'profile',
      'thermalAtStart': 'none',
      'flutterVersion': '3.47.6',
      'engineRevision': 'abc',
      'appCommit': 'unknown',
      'textScale': 1.0,
      'locale': 'en-GB',
    },
    'valid': true,
    'reasons': <Object?>[],
    'frameCount': frameCount,
    'flushTimedOut': false,
    'flushMicros': 0,
    'callbackMicros': 0,
    'rateReads': <Object?>[],
    'parts': <Object?>[],
    'issues': <Object?>[],
    'activity': <Object?>[],
    'pages': <Object?>[],
  };
}

/// [count] frame rows, the first numbered 1.
List<List<int>> framesOf(int count) {
  return [
    for (var frame = 1; frame <= count; frame++)
      [frame, frame * 8333, 0, 2000, 2000, 4000, 0, 0, 0, 0],
  ];
}

/// The lines of a run [runId] of [frameCount] frames: its start line, its
/// report in lines of up to [chunkLength] characters, then its frames, 20
/// a line.
({String start, List<String> report, List<String> frames}) linesOf(
  int runId,
  int frameCount, {
  Map<String, Object?>? report,
  int chunkLength = defaultChunkLength,
}) {
  final writer = LineWriter(runId, chunkLength: chunkLength);
  return (
    start: writer.start(),
    report: writer.report(report ?? reportOf(runId, frameCount)),
    frames: writer.frames(framesOf(frameCount)),
  );
}
