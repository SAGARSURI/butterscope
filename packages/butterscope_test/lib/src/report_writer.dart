import 'package:butterscope/butterscope.dart';
import 'package:butterscope_report/butterscope_report.dart';

/// Prints a run's lines to the device log, as [LineWriter] formats them
/// (`docs/report-schema.md`).
///
/// [start] prints the `start` line before the first test, so a run that
/// never reports still shows. [write] prints the report's lines, then its
/// frames' lines.
final class ReportWriter {
  /// Creates a writer that prints each line with [_emit], with up to
  /// [chunkLength] characters of report JSON and [framesPerLine] frames a
  /// line.
  ///
  /// Throws a [RangeError] when either is below 1, since no line could
  /// then carry anything.
  new(
    this._emit, {
    this.chunkLength = defaultChunkLength,
    this.framesPerLine = defaultFramesPerLine,
  }) {
    // Checks both now, not when the run's first line is printed.
    _lines(0);
  }

  final void Function(String line) _emit;

  /// The most characters of report JSON a `report` line carries.
  final int chunkLength;

  /// The frames a `frames` line carries, except the last.
  final int framesPerLine;

  /// Prints the `start` line of the run identified by [runId].
  void start(int runId) => _emit(_lines(runId).start());

  /// Prints [report]'s `report` lines, then its `frames` lines.
  void write(RunReport report) {
    final lines = _lines(report.runId);
    lines.report(report.toJson()).forEach(_emit);
    lines.frames(report.frameRows).forEach(_emit);
  }

  LineWriter _lines(int runId) {
    return LineWriter(
      runId,
      chunkLength: chunkLength,
      framesPerLine: framesPerLine,
    );
  }
}
