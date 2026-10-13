import 'package:butterscope_cli/src/collect.dart';
import 'package:butterscope_report/butterscope_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/runs.dart';

void main() {
  // 45 frames at 20 a line: lines of 20, 20 and 5.
  final run = linesOf(7, 45);

  RunOutcome onlyRun(List<String> log) => collectLog(log).runs.single;

  test('builds the file of a run that arrived whole', () {
    final log = collectLog([run.start, ...run.report, ...run.frames]);

    expect(log.isWhole, isTrue);
    final file = log.runs.single.file!;
    expect(file['runId'], 7);
    expect(file['frames'], framesOf(45));
    expect(file['framesMissing'], isEmpty);
  });

  test('lists the frames a lost frames line held', () {
    final outcome = onlyRun([
      run.start,
      ...run.report,
      run.frames[0],
      run.frames[2],
    ]);

    // Line 2 held frames 20 to 39, counted from 0.
    expect(outcome.file!['framesMissing'], [
      [20, 20],
    ]);
    expect(outcome.problems, ['missingLine, frames, line 2']);
  });

  test("counts a lost last line's frames from the report", () {
    final outcome = onlyRun([run.start, ...run.report, ...run.frames.take(2)]);

    // Lines 1 and 2 held 40 frames; the report counts 45, so 5 are lost.
    expect(outcome.file!['framesMissing'], [
      [40, 5],
    ]);
  });

  test('counts every frame lost when no frames line arrived', () {
    final outcome = onlyRun([run.start, ...run.report]);

    expect(outcome.file!['framesMissing'], [
      [0, 45],
    ]);
    expect(outcome.problems, ['no frames line arrived']);
  });

  test('writes no file when a report line is lost', () {
    final split = linesOf(7, 45, chunkLength: 100);
    final outcome = onlyRun([
      split.start,
      ...split.report.skip(1),
      ...split.frames,
    ]);

    expect(split.report.length, greaterThan(1));
    expect(outcome.file, isNull);
    expect(outcome.problems, ['missingLine, report, line 1']);
  });

  test('writes no file for a report that is not schema v1', () {
    final report = reportOf(7, 45)..remove('runId');
    final broken = linesOf(7, 45, report: report);
    final outcome = onlyRun([broken.start, ...broken.report, ...broken.frames]);

    expect(outcome.file, isNull);
    expect(outcome.problems, ['not schema v1: runId: missing']);
  });

  test('writes no file for a report whose JSON is null', () {
    final writer = LineWriter(7);
    final outcome = onlyRun([writer.start(), ...writer.report(null)]);

    expect(outcome.file, isNull);
    expect(outcome.problems, ['not schema v1: expected an object, got null']);
  });

  test('checks a report read back beside a damaged report line', () {
    final report = reportOf(7, 45)..remove('frameCount');
    final broken = linesOf(7, 45, report: report);
    // The report fits one line, so a damaged line 2 lies past its count.
    final outcome = onlyRun([
      broken.start,
      ...broken.report,
      'BSCOPE 7 report 2/2 00000000 x',
      ...broken.frames,
    ]);

    expect(broken.report, hasLength(1));
    expect(outcome.file, isNull);
    expect(outcome.problems, [
      'badChecksum, report, line 2',
      'not schema v1: frameCount: missing',
    ]);
  });

  test('writes no file when the report names another run', () {
    final other = linesOf(7, 45, report: reportOf(42, 45));
    final outcome = onlyRun([other.start, ...other.report, ...other.frames]);

    expect(outcome.file, isNull);
    expect(outcome.problems, [
      'the report names run 42, but its lines name run 7',
    ]);
  });

  test('says when the frames lines hold another count than the report', () {
    final report = reportOf(7, 50);
    final short = linesOf(7, 45, report: report);
    final outcome = onlyRun([short.start, ...short.report, ...short.frames]);

    expect(outcome.problems, [
      'the report counts 50 frames, but the frames lines held 45 and lost 0',
    ]);
  });

  test('names a run whose start line is missing, and still writes it', () {
    final outcome = onlyRun([...run.report, ...run.frames]);

    expect(outcome.file, isNotNull);
    expect(outcome.problems, ['no start line']);
  });

  test('is not whole when the log holds no run', () {
    expect(collectLog(['hello']).isWhole, isFalse);
  });

  test('is not whole when a tagged line names no run', () {
    final log = collectLog([
      run.start,
      ...run.report,
      ...run.frames,
      'BSCOPE x',
    ]);

    expect(log.strays, ['BSCOPE x']);
    expect(log.isWhole, isFalse);
  });
}
