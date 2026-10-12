import 'dart:convert';
import 'dart:math' as math;

import 'package:butterscope_report/src/crc32.dart';
import 'package:butterscope_report/src/line_format.dart';

/// Turns one run's report into the lines the phone prints.
///
/// ```text
/// BSCOPE <runId> start
/// BSCOPE <runId> report <i>/<n> <crc> <json chunk>
/// BSCOPE <runId> frames <i>/<n> <crc> <json array of frames>
/// ```
///
/// `<i>` counts from 1 within its kind, and `<crc>` is [crc32] of the
/// payload, so a reader knows which lines are missing and which arrived
/// mangled. Frames have lines of their own: a lost frame line costs
/// [framesPerLine] frames, not the report.
final class LineWriter {
  /// Creates a writer for the run identified by [runId].
  ///
  /// Throws a [RangeError] when [chunkLength] or [framesPerLine] is below
  /// 1, since no line could then carry anything.
  new(
    this.runId, {
    this.chunkLength = defaultChunkLength,
    this.framesPerLine = defaultFramesPerLine,
  }) {
    checkAtLeastOne(chunkLength, 'chunkLength');
    checkAtLeastOne(framesPerLine, 'framesPerLine');
  }

  /// The run's id, on every line it prints.
  final int runId;

  /// The most characters of report JSON a `report` line carries.
  final int chunkLength;

  /// The frames a `frames` line carries, except the last.
  final int framesPerLine;

  /// The line printed before the run's first test, so a reader can tell a
  /// run that started and never reported.
  String start() => '$lineTag $runId start';

  /// The `report` lines that carry [json], encoded with [jsonEncode].
  List<String> report(Object? json) =>
      _numbered(LineKind.report, chunk(jsonEncode(json), chunkLength));

  /// The `frames` lines that carry [frames], each a JSON array of up to
  /// [framesPerLine] of them, in order. No frames, no lines.
  List<String> frames(List<Object?> frames) => _numbered(LineKind.frames, [
    for (var i = 0; i < frames.length; i += framesPerLine)
      jsonEncode(frames.sublist(i, math.min(i + framesPerLine, frames.length))),
  ]);

  List<String> _numbered(LineKind kind, List<String> payloads) => [
    for (final (i, payload) in payloads.indexed)
      [
        lineTag,
        runId,
        kind.name,
        '${i + 1}/${payloads.length}',
        crc32(payload),
        payload,
      ].join(' '),
  ];
}
