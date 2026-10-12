import 'package:butterscope_report/butterscope_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// A run of 45 one-number frames at 20 a line: lines 1/3 (frames 0-19),
/// 2/3 (20-39) and 3/3 (40-44); and a report in chunks of 10.
const Map<String, Object> report = {'schema': 1, 'name': 'feed scroll'};
final List<List<int>> frames = [
  for (var i = 0; i < 45; i++) [i],
];
final LineWriter writer = LineWriter(42, chunkLength: 10);
final List<String> reportLines = writer.report(report);
final List<String> frameLines = writer.frames(frames);
final List<String> whole = [writer.start(), ...reportLines, ...frameLines];

CollectedRun readOne(List<String> log) {
  final read = readLog(log);
  expect(read.runs, hasLength(1));
  return read.runs.single;
}

/// [line] with one character of its payload changed.
String mangle(String line) => '${line.substring(0, line.length - 1)}#';

void main() {
  test('the report has 4 chunks, the frames 3 lines', () {
    // jsonEncode(report) is {"schema":1,"name":"feed scroll"}, 32
    // characters: chunks of 10 make 4 lines.
    expect(reportLines, hasLength(4));
    expect(frameLines, hasLength(3));
  });

  test('reads back a whole run', () {
    final run = readOne(whole);

    expect(run.runId, 42);
    expect(run.started, isTrue);
    expect(run.report, report);
    expect(run.frames, frames);
    expect(run.framesMissing, isEmpty);
    expect(run.problems, isEmpty);
    expect(run.isWhole, isTrue);
  });

  test("ignores logcat's and syslog's prefixes and a carriage return", () {
    final prefixed = [
      for (final (i, line) in whole.indexed)
        if (i.isEven)
          'I/flutter (12345): $line\r'
        else
          'Oct 12 Runner(Flutter)[88] <Notice>: flutter: $line',
    ];

    expect(readOne(prefixed).isWhole, isTrue);
  });

  test('counts a line printed twice once', () {
    // A log holding both the flutter drive transcript and logcat.
    expect(readOne([...whole, ...whole]).isWhole, isTrue);
  });

  test('ignores lines without the tag, and schema 0 lines', () {
    final log = ['hello', 'BSCOPE-REPORT 42 1 1 {}', ...whole];

    expect(readLog(log).strays, isEmpty);
    expect(readOne(log).isWhole, isTrue);
  });

  test('names a missing report line and gives no report', () {
    final log = [...whole]..remove(reportLines[1]);
    final run = readOne(log);

    expect(run.report, isNull);
    expect(run.problems, [
      const LineProblem(
        ProblemKind.missingLine,
        lines: LineKind.report,
        index: 2,
      ),
    ]);
    // The frames do not depend on the report.
    expect(run.frames, frames);
  });

  test('names a mangled report line as a bad checksum', () {
    final log = [...whole]..[2] = mangle(reportLines[1]);
    final run = readOne(log);

    expect(run.report, isNull);
    expect(run.problems, [
      const LineProblem(
        ProblemKind.badChecksum,
        lines: LineKind.report,
        index: 2,
      ),
    ]);
  });

  test('takes the whole copy when another copy is mangled', () {
    expect(readOne([mangle(reportLines[1]), ...whole]).isWhole, isTrue);
  });

  test('names two whole copies of a line that differ', () {
    final other = LineWriter(42, chunkLength: 10).report({'other': 1});
    final run = readOne([...whole, other.first]);

    expect(
      run.problems,
      contains(
        const LineProblem(
          ProblemKind.conflictingLine,
          lines: LineKind.report,
          index: 1,
        ),
      ),
    );
  });

  test('names lines that disagree on their count', () {
    // A one-chunk report claims 1/1 where the run's report lines say /4.
    final other = LineWriter(42).report({'x': 1}).single;
    final run = readOne([...whole, other]);

    expect(
      run.problems,
      contains(
        const LineProblem(
          ProblemKind.countMismatch,
          lines: LineKind.report,
          detail: '1, 4',
        ),
      ),
    );
  });

  test('lists the frames a lost middle line held', () {
    final log = [...whole]..remove(frameLines[1]);
    final run = readOne(log);

    // Line 2 of 3 held frames 20 to 39.
    expect(run.framesMissing, [const FrameGap(20, 20)]);
    expect(run.frames, [...frames.take(20), ...frames.skip(40)]);
    expect(run.report, report);
    expect(run.isWhole, isFalse);
  });

  test('lists a lost last line as running to the end', () {
    final log = [...whole]..remove(frameLines[2]);

    // Line 3 of 3 starts at frame 40; how many it held is in the report.
    expect(readOne(log).framesMissing, [const FrameGap(40, null)]);
  });

  test('joins neighbouring lost lines into one gap', () {
    final log = [...whole]
      ..remove(frameLines[0])
      ..remove(frameLines[1]);

    expect(readOne(log).framesMissing, [const FrameGap(0, 40)]);
  });

  test('names a frames line that is not a JSON array', () {
    final bad = LineWriter(42)
        .report({'x': 1})
        .single
        .replaceFirst('report', 'frames');
    final run = readOne([writer.start(), ...reportLines, bad]);

    expect(run.problems.single.kind, ProblemKind.badJson);
    expect(run.framesMissing, [const FrameGap(0, null)]);
  });

  test('names a run that started and never reported', () {
    final run = readOne([writer.start()]);

    expect(run.started, isTrue);
    expect(run.report, isNull);
    expect(run.problems, [const LineProblem(ProblemKind.noReport)]);
  });

  test('names a run whose frames arrived and report did not', () {
    final run = readOne(frameLines);

    expect(run.started, isFalse);
    expect(run.problems, [const LineProblem(ProblemKind.noReport)]);
    expect(run.frames, frames);
  });

  test('names a line whose header cannot be read', () {
    final run = readOne([...whole, 'BSCOPE 42 report 1of4 abc {}']);

    expect(run.problems.single.kind, ProblemKind.malformedLine);
  });

  test('lists a tagged line with no readable run id', () {
    final read = readLog([...whole, 'BSCOPE 4x2 start']);

    expect(read.strays, ['BSCOPE 4x2 start']);
    expect(read.runs.single.isWhole, isTrue);
  });

  test('keeps interleaved runs apart, in the order they first appear', () {
    final other = LineWriter(7);
    final log = [
      other.start(),
      for (var i = 0; i < whole.length; i++) ...[
        whole[i],
        if (i == 0) ...other.report({'run': 7}),
      ],
    ];
    final read = readLog(log);

    expect([for (final run in read.runs) run.runId], [7, 42]);
    expect(read.runs.first.report, {'run': 7});
    expect(read.runs.last.isWhole, isTrue);
  });
}
