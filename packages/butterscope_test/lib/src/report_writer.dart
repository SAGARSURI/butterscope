import 'dart:convert';

import 'package:butterscope_report/butterscope_report.dart' show chunk;

/// The tag that starts every report line.
const String reportTag = 'BSCOPE-REPORT';

/// Prints a report as numbered lines short enough for a device log.
///
/// Android's logcat cuts long lines and drops lines that come too fast
/// (`docs/decisions/0002-m2-recorder-findings.md`), so the report's JSON is
/// split into chunks of at most [chunkLength] characters, each on a line:
/// `BSCOPE-REPORT <run id> <index> <count> <chunk>`, with the index counted
/// from 1. A reader joins the chunks of one run id in index order and knows
/// from the count whether any went missing. A chunk never splits a
/// surrogate pair ([chunk]). M7 replaces this format with
/// `butterscope_report`'s lines.
final class ReportWriter {
  /// Creates a writer that prints each line with [_emit].
  ///
  /// Throws a [RangeError] when [chunkLength] is below 1, since no chunk
  /// could then carry any of the report.
  new(this._emit, {this.chunkLength = 800}) {
    if (chunkLength < 1) {
      throw RangeError.value(chunkLength, 'chunkLength', 'must be at least 1');
    }
  }

  final void Function(String line) _emit;

  /// The most characters of JSON a line carries.
  final int chunkLength;

  /// Prints [json] as the report of the run identified by [runId].
  void write(Object? json, {required int runId}) {
    final chunks = chunk(jsonEncode(json), chunkLength);
    for (var i = 0; i < chunks.length; i++) {
      _emit('$reportTag $runId ${i + 1} ${chunks.length} ${chunks[i]}');
    }
  }
}
