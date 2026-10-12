import 'dart:convert';
import 'dart:math' as math;

import 'package:butterscope_report/src/collected_run.dart';
import 'package:butterscope_report/src/crc32.dart';
import 'package:butterscope_report/src/line_format.dart';

/// Everything a log held: each run's lines read back, and the tagged lines
/// that name no run.
final class LogRead {
  /// Creates what a log held.
  const new(this.runs, this.strays);

  /// Each run, in the order its first line appears.
  final List<CollectedRun> runs;

  /// Lines that carry the tag but no readable run id, as read. Their run
  /// cannot be told, so they are listed rather than dropped.
  final List<String> strays;
}

/// Reads every run's lines in [log], one log line per element, as written
/// by `LineWriter` with [framesPerLine] frames a `frames` line.
///
/// Anything before the tag is ignored, so logcat's and syslog's prefixes
/// may stay, and a trailing carriage return is dropped. A line may appear
/// more than once, as it does when a log holds both the `flutter drive`
/// transcript and logcat: whole copies that agree count once.
LogRead readLog(
  Iterable<String> log, {
  int framesPerLine = defaultFramesPerLine,
}) {
  checkAtLeastOne(framesPerLine, 'framesPerLine');
  final runs = <int, _RunLines>{};
  final strays = <String>[];
  for (final line in log) {
    final at = line.indexOf('$lineTag ');
    if (at < 0) continue;
    var text = line.substring(at);
    if (text.endsWith('\r')) text = text.substring(0, text.length - 1);
    final fields = text.split(' ');
    final runId = int.tryParse(fields[1]);
    if (runId == null) {
      strays.add(line);
      continue;
    }
    runs.putIfAbsent(runId, _RunLines.new).add(fields, text);
  }
  return LogRead([
    for (final MapEntry(key: runId, value: lines) in runs.entries)
      lines.finish(runId, framesPerLine),
  ], strays);
}

/// The lines read so far for one run.
final class _RunLines {
  bool started = false;
  final List<LineProblem> problems = [];
  final _Numbered report = _Numbered(LineKind.report);
  final _Numbered frames = _Numbered(LineKind.frames);

  /// Takes one line, already split on spaces into [fields], the tag and a
  /// readable run id first.
  void add(List<String> fields, String text) {
    if (fields.length == 3 && fields[2] == 'start') {
      started = true;
      return;
    }
    final header = _Header.parse(fields);
    if (header == null) {
      problems.add(LineProblem(ProblemKind.malformedLine, detail: text));
      return;
    }
    (header.kind == LineKind.report ? report : frames).add(header);
  }

  CollectedRun finish(int runId, int framesPerLine) {
    if (report.isEmpty) {
      problems.add(const LineProblem(ProblemKind.noReport));
    }
    report.checkCounts(problems);
    frames.checkCounts(problems);
    final json = report.joined(problems);
    final rows = <Object?>[];
    final gaps = _Gaps();
    for (var index = 1; index <= frames.count; index++) {
      final payload = frames.payload(index, problems);
      final decoded = payload == null ? null : _frameArray(payload, index);
      if (decoded is List<Object?>) {
        rows.addAll(decoded);
        continue;
      }
      if (decoded is LineProblem) problems.add(decoded);
      final last = index == frames.count;
      gaps.add((index - 1) * framesPerLine, last ? null : framesPerLine);
    }
    return CollectedRun(
      runId: runId,
      started: started,
      report: json == null ? null : _decodeReport(json, problems),
      frames: rows,
      framesMissing: gaps.list,
      problems: problems,
    );
  }
}

/// One numbered line's header and payload.
final class _Header {
  const new(
    this.kind,
    this.index,
    this.count,
    this.payload, {
    required this.isWhole,
  });

  final LineKind kind;
  final int index;
  final int count;
  final String payload;

  /// Whether the line matches its CRC. When it does not, [index] and
  /// [count] may be mangled too.
  final bool isWhole;

  /// Reads `<tag> <runId> <kind> <i>/<n> <crc> <payload>`, the payload
  /// spaces and all, or returns `null` when any part cannot be read or the
  /// line claims more than [maxLineCount] lines.
  static _Header? parse(List<String> fields) {
    if (fields.length < 6) return null;
    final kind = LineKind.values.asNameMap()[fields[2]];
    final numbers = fields[3].split('/');
    if (kind == null || numbers.length != 2) return null;
    final index = int.tryParse(numbers[0]);
    final count = int.tryParse(numbers[1]);
    if (index == null || count == null || index < 1 || index > count) {
      return null;
    }
    if (count > maxLineCount) return null;
    final payload = fields.skip(5).join(' ');
    final signed = '${fields[1]} ${fields[2]} ${fields[3]} $payload';
    return _Header(
      kind,
      index,
      count,
      payload,
      isWhole: crc32(signed) == fields[4],
    );
  }
}

/// The numbered lines of one kind, for one run.
final class _Numbered {
  new(this.kind);

  final LineKind kind;

  /// Each line's distinct whole payloads: more than one is a dispute.
  final Map<int, Set<String>> _whole = {};
  final Set<int> _mangled = {};
  final Set<int> _counts = {};
  final Set<int> _mangledCounts = {};

  bool get isEmpty => _counts.isEmpty && _mangledCounts.isEmpty;

  /// How many lines of this kind there should be: the most any whole line
  /// claimed, so a line that claims fewer cannot hide the rest. Only when
  /// no line arrived whole, the most any mangled line claimed.
  int get count =>
      (_counts.isEmpty ? _mangledCounts : _counts).fold(0, math.max);

  void add(_Header line) {
    if (!line.isWhole) {
      _mangled.add(line.index);
      _mangledCounts.add(line.count);
      return;
    }
    _counts.add(line.count);
    (_whole[line.index] ??= {}).add(line.payload);
  }

  /// Line [index]'s payload, or `null` after adding to [problems] why it
  /// has none: missing, mangled, or two whole copies that differ.
  String? payload(int index, List<LineProblem> problems) {
    final copies = _whole[index];
    if (copies != null && copies.length == 1) return copies.single;
    final ProblemKind problem;
    if (copies != null) {
      problem = ProblemKind.conflictingLine;
    } else if (_mangled.contains(index)) {
      problem = ProblemKind.badChecksum;
    } else {
      problem = ProblemKind.missingLine;
    }
    problems.add(LineProblem(problem, lines: kind, index: index));
    return null;
  }

  /// Adds a problem to [problems] when whole lines disagree on their count.
  void checkCounts(List<LineProblem> problems) {
    if (_counts.length < 2) return;
    problems.add(
      LineProblem(
        ProblemKind.countMismatch,
        lines: kind,
        detail: (_counts.toList()..sort()).join(', '),
      ),
    );
  }

  /// Every payload joined in order, or `null` when there are none, any is
  /// missing, or the lines disagree on their count; each line without a
  /// payload goes in [problems].
  String? joined(List<LineProblem> problems) {
    if (isEmpty) return null;
    final payloads = [
      for (var index = 1; index <= count; index++) payload(index, problems),
    ];
    if (payloads.contains(null) || _counts.length > 1) return null;
    return payloads.join();
  }
}

/// Frame gaps, with each one that starts where the one before it ends
/// joined to it.
final class _Gaps {
  final List<FrameGap> list = [];

  void add(int first, int? count) {
    final previous = list.isEmpty ? null : list.last;
    final previousCount = previous?.count;
    if (previous != null &&
        previousCount != null &&
        previous.first + previousCount == first) {
      list.last = FrameGap(
        previous.first,
        count == null ? null : previousCount + count,
      );
      return;
    }
    list.add(FrameGap(first, count));
  }
}

/// A `frames` line's payload as its list of frames, or the problem that
/// says why it is not one.
Object _frameArray(String payload, int index) {
  try {
    final decoded = jsonDecode(payload);
    if (decoded is List<Object?>) return decoded;
    return LineProblem(
      ProblemKind.badJson,
      lines: LineKind.frames,
      index: index,
      detail: 'not a JSON array',
    );
  } on FormatException catch (error) {
    return LineProblem(
      ProblemKind.badJson,
      lines: LineKind.frames,
      index: index,
      detail: error.message,
    );
  }
}

/// The report decoded from [json], or `null` after adding to [problems]
/// why it does not decode.
Object? _decodeReport(String json, List<LineProblem> problems) {
  try {
    return jsonDecode(json);
  } on FormatException catch (error) {
    problems.add(
      LineProblem(
        ProblemKind.badJson,
        lines: LineKind.report,
        detail: error.message,
      ),
    );
    return null;
  }
}
