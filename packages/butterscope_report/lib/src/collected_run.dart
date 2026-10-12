import 'package:butterscope_report/src/line_format.dart';
import 'package:meta/meta.dart';

/// One run, as read back from a log.
final class CollectedRun {
  /// Creates a run read back from a log.
  const new({
    required this.runId,
    required this.started,
    required this.report,
    required this.frames,
    required this.framesMissing,
    required this.problems,
  });

  /// The id its lines carry.
  final int runId;

  /// Whether its `start` line was read.
  final bool started;

  /// The decoded report, or `null` when any of its `report` lines is
  /// missing or mangled, or the joined JSON does not decode.
  final Object? report;

  /// The frames from every `frames` line that arrived whole, in order.
  final List<Object?> frames;

  /// The frames the missing or mangled `frames` lines held. Empty when no
  /// `frames` line arrived at all, since then their count is unknown: the
  /// report says how many frames it should have.
  final List<FrameGap> framesMissing;

  /// Everything wrong with its lines, in the order found.
  final List<LineProblem> problems;

  /// Whether every line arrived whole: a report, and no problem.
  bool get isWhole => report != null && problems.isEmpty;
}

/// A run of frames lost with the `frames` lines that held them.
@immutable
final class FrameGap {
  /// Creates a gap from frame [first], counted from 0, of [count] frames,
  /// or to the end of the run when [count] is `null`.
  const new(this.first, this.count);

  /// The first frame lost, counted from 0.
  final int first;

  /// How many frames were lost, or `null` when the run's last `frames`
  /// line was among them: its frame count is known only from the report.
  final int? count;

  @override
  bool operator ==(Object other) =>
      other is FrameGap && other.first == first && other.count == count;

  @override
  int get hashCode => Object.hash(first, count);

  @override
  String toString() => 'FrameGap($first, $count)';
}

/// What can be wrong with a run's lines.
enum ProblemKind {
  /// Other lines of the run arrived but no `report` line did: the app
  /// stopped, or the log did, before the report was printed.
  noReport,

  /// A numbered line never arrived.
  missingLine,

  /// A numbered line arrived, but its payload does not match its CRC, and
  /// no whole copy arrived.
  badChecksum,

  /// Two whole copies of one numbered line differ.
  conflictingLine,

  /// Lines of one kind disagree on how many there are.
  countMismatch,

  /// A line starts with the tag and this run's id, but the rest cannot be
  /// read.
  malformedLine,

  /// Every line arrived whole, but the payload is not the JSON expected:
  /// the joined report does not decode, or a `frames` line is not an array.
  badJson,
}

/// One thing wrong with a run's lines.
@immutable
final class LineProblem {
  /// Creates a problem of [kind], with the [lines] kind and line [index]
  /// it concerns when it concerns one.
  const new(this.kind, {this.lines, this.index, this.detail});

  /// What is wrong.
  final ProblemKind kind;

  /// The kind of line it concerns, if one.
  final LineKind? lines;

  /// The line's number, counted from 1, if one.
  final int? index;

  /// More, for people: the line as read, or the decoding error.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is LineProblem &&
      other.kind == kind &&
      other.lines == lines &&
      other.index == index &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, lines, index, detail);

  @override
  String toString() => [
    kind.name,
    ?lines?.name,
    if (index != null) 'line $index',
    ?detail,
  ].join(', ');
}
