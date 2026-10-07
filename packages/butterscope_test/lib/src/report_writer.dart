import 'dart:convert';
import 'dart:math' as math;

/// The tag that starts every report line.
const String reportTag = 'BSCOPE-REPORT';

/// Prints a report as numbered lines short enough for a device log.
///
/// Android's logcat cuts long lines and drops lines that come too fast
/// (`docs/decisions/0002-m2-recorder-findings.md`), so the report's JSON is
/// split into chunks of at most [chunkLength] characters, each on a line:
/// `BSCOPE-REPORT <run id> <index> <count> <chunk>`, with the index counted
/// from 1. A reader joins the chunks of one run id in index order and knows
/// from the count whether any went missing. M7 freezes this format.
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
    final chunks = _chunks(jsonEncode(json));
    for (var i = 0; i < chunks.length; i++) {
      _emit('$reportTag $runId ${i + 1} ${chunks.length} ${chunks[i]}');
    }
  }

  /// Splits [text] into chunks of at most [chunkLength] code units. A cut
  /// that would fall inside a surrogate pair (before a low surrogate,
  /// 0xDC00 to 0xDFFF) moves back one, so no chunk holds half a character
  /// a log could mangle.
  List<String> _chunks(String text) {
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = math.min(start + chunkLength, text.length);
      final next = end < text.length ? text.codeUnitAt(end) : 0;
      final splitsPair = next >= 0xDC00 && next <= 0xDFFF;
      if (splitsPair && end - start > 1) end--;
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }
}
