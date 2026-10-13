import 'dart:math' as math;

import 'package:butterscope_report/butterscope_report.dart';

/// What `collect` made of one run.
final class RunOutcome {
  /// Creates the outcome of the run [runId].
  const new(this.runId, {required this.file, required this.problems});

  /// The id its lines carry.
  final int runId;

  /// The run's file as JSON, or `null` when none can be written: its
  /// report did not arrive whole, or does not match schema v1.
  final Map<String, Object?>? file;

  /// Everything wrong with the run, for people, in the order found. A run
  /// with none arrived whole.
  final List<String> problems;
}

/// Everything `collect` made of a log.
final class LogOutcome {
  /// Creates what a log held.
  const new(this.runs, this.strays);

  /// Each run, in the order its first line appears.
  final List<RunOutcome> runs;

  /// Lines that carry the tag but no readable run id.
  final List<String> strays;

  /// Whether the log held at least one run and every one arrived whole.
  bool get isWhole {
    return runs.isNotEmpty &&
        strays.isEmpty &&
        runs.every((run) => run.problems.isEmpty);
  }
}

/// Reads every run in [log], one log line per element, and builds each
/// run's file (`docs/report-schema.md`, "Collected file").
LogOutcome collectLog(Iterable<String> log) {
  final read = readLog(log);
  return LogOutcome([for (final run in read.runs) _collect(run)], read.strays);
}

RunOutcome _collect(CollectedRun run) {
  final problems = [
    if (!run.started) 'no start line',
    for (final problem in run.problems) '$problem',
  ];
  final report = run.report;
  final unusable = [
    for (final problem in _schemaProblems(run)) 'not schema v1: $problem',
    if (report case {'runId': final int id} when id != run.runId)
      'the report names run $id, but its lines name run ${run.runId}',
  ];
  if (report is! Map<String, Object?> || unusable.isNotEmpty) {
    return RunOutcome(
      run.runId,
      file: null,
      problems: [...problems, ...unusable],
    );
  }
  final frameCount = report['frameCount']! as int;
  final missing = _framesMissing(run, frameCount);
  final lost = missing.fold(0, (sum, gap) => sum + gap.$2);
  if (missing.isNotEmpty && run.framesMissing.isEmpty) {
    problems.add('no frames line arrived');
  }
  if (run.frames.length + lost != frameCount) {
    problems.add(
      'the report counts $frameCount frames, but the frames lines held '
      '${run.frames.length} and lost $lost',
    );
  }
  return RunOutcome(
    run.runId,
    file: {
      ...report,
      'frames': run.frames,
      'framesMissing': [
        for (final (first, count) in missing) [first, count],
      ],
    },
    problems: problems,
  );
}

/// Where the report and frames break schema v1. Every report read back is
/// checked, even when a damaged line was found beside it. No report is
/// checked only when no line problem explains it, so its JSON was `null`.
List<SchemaProblem> _schemaProblems(CollectedRun run) {
  final reportLost = run.problems.any(
    (problem) =>
        problem.kind == ProblemKind.noReport ||
        problem.lines == LineKind.report,
  );
  return [
    if (run.report != null || !reportLost) ...checkReport(run.report),
    ...checkFrames(run.frames),
  ];
}

/// The frames lost, as `(first, count)`. A gap that runs to the end of the
/// run ends at [frameCount]. When no `frames` line arrived at all, every
/// frame the report counts is lost.
List<(int, int)> _framesMissing(CollectedRun run, int frameCount) {
  if (run.frames.isEmpty && run.framesMissing.isEmpty) {
    return [if (frameCount > 0) (0, frameCount)];
  }
  return [
    for (final FrameGap(:first, :count) in run.framesMissing)
      (first, count ?? math.max(0, frameCount - first)),
  ];
}
