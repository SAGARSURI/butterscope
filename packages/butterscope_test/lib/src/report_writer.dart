import 'dart:convert';

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
  new(this._emit, {this.chunkLength = 800});

  final void Function(String line) _emit;

  /// The most characters of JSON a line carries.
  final int chunkLength;

  /// Prints [json] as the report of the run identified by [runId].
  void write(Object? json, {required int runId}) {
    final text = jsonEncode(json);
    final count = (text.length + chunkLength - 1) ~/ chunkLength;
    for (var i = 0; i < count; i++) {
      final end = (i + 1) * chunkLength;
      final chunk = text.substring(
        i * chunkLength,
        end < text.length ? end : text.length,
      );
      _emit('$reportTag $runId ${i + 1} $count $chunk');
    }
  }
}
