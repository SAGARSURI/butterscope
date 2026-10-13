import 'package:butterscope/butterscope.dart';
import 'package:butterscope_report/butterscope_report.dart';

/// Prints a run's lines to the device log, as [LineWriter] formats them
/// (`docs/report-schema.md`).
///
/// [start] prints the `start` line before the first test, so a run that
/// never reports still shows. [write] prints the report's lines, then its
/// frames' lines, pausing after every [linesPerPause] lines.
///
/// The pause is for Android. Its log daemon drops lines that come faster
/// than it reads them: in M7's first S24 run, a run's 219 lines printed
/// within 6 ms, and every line after about the 170th was lost, from
/// logcat and from the `flutter drive` transcript alike.
final class ReportWriter {
  /// Creates a writer that prints each line with [_emit], with up to
  /// [chunkLength] characters of report JSON and [framesPerLine] frames a
  /// line, and waits [pause] with [_wait] after every [linesPerPause]
  /// lines.
  ///
  /// Throws a [RangeError] when [chunkLength], [framesPerLine] or
  /// [linesPerPause] is below 1, since no line could then carry anything,
  /// or no line be printed between pauses.
  new(
    this._emit, {
    this.chunkLength = defaultChunkLength,
    this.framesPerLine = defaultFramesPerLine,
    this.linesPerPause = 16,
    this.pause = const Duration(milliseconds: 20),
    this._wait = Future<void>.delayed,
  }) {
    // Checks them now, not when the run's first line is printed.
    _lines(0);
    if (linesPerPause < 1) {
      throw RangeError.range(linesPerPause, 1, null, 'linesPerPause');
    }
  }

  final void Function(String line) _emit;
  final Future<void> Function(Duration) _wait;

  /// The most characters of report JSON a `report` line carries.
  final int chunkLength;

  /// The frames a `frames` line carries, except the last.
  final int framesPerLine;

  /// The lines printed between two pauses.
  final int linesPerPause;

  /// How long each pause lasts.
  final Duration pause;

  /// Prints the `start` line of the run identified by [runId].
  void start(int runId) => _emit(_lines(runId).start());

  /// Prints [report]'s `report` lines, then its `frames` lines, and
  /// completes once the last is printed.
  Future<void> write(RunReport report) async {
    final writer = _lines(report.runId);
    final lines = [
      ...writer.report(report.toJson()),
      ...writer.frames(report.frameRows),
    ];
    for (final (i, line) in lines.indexed) {
      if (i > 0 && i % linesPerPause == 0) await _wait(pause);
      _emit(line);
    }
  }

  LineWriter _lines(int runId) {
    return LineWriter(
      runId,
      chunkLength: chunkLength,
      framesPerLine: framesPerLine,
    );
  }
}
