import 'dart:convert';

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
    (header.kind == LineKind.report ? report : frames).add(header, problems);
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
  const new(this.kind, this.index, this.count, this.crc, this.payload);

  final LineKind kind;
  final int index;
  final int count;
  final String crc;
  final String payload;

  /// Reads `<tag> <runId> <kind> <i>/<n> <crc> <payload>`, the payload
  /// spaces and all, or returns `null` when any part cannot be read.
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
    return _Header(kind, index, count, fields[4], fields.skip(5).join(' '));
  }
}

/// The numbered lines of one kind, for one run.
final class _Numbered {
  new(this.kind);

  final LineKind kind;
  final Map<int, String> _whole = {};
  final Map<int, String> _mangled = {};
  final Set<int> _counts = {};

  bool get isEmpty => _counts.isEmpty;

  /// How many lines of this kind there should be: the most any line
  /// claimed, so a line that claims fewer cannot hide the rest.
  int get count =>
      _counts.fold(0, (most, count) => count > most ? count : most);

  void add(_Header line, List<LineProblem> problems) {
    _counts.add(line.count);
    if (crc32(line.payload) != line.crc) {
      _mangled[line.index] ??= line.payload;
      return;
    }
    final earlier = _whole.putIfAbsent(line.index, () => line.payload);
    if (earlier != line.payload) {
      problems.add(
        LineProblem(
          ProblemKind.conflictingLine,
          lines: kind,
          index: line.index,
        ),
      );
    }
  }

  /// Line [index]'s payload, or `null` after adding to [problems] why it
  /// has none.
  String? payload(int index, List<LineProblem> problems) {
    final whole = _whole[index];
    if (whole != null) return whole;
    problems.add(
      LineProblem(
        _mangled.containsKey(index)
            ? ProblemKind.badChecksum
            : ProblemKind.missingLine,
        lines: kind,
        index: index,
      ),
    );
    return null;
  }

  /// Adds a problem to [problems] when lines disagree on their count.
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

  /// Every payload joined in order, or `null` when there are none or any
  /// is missing; each missing one goes in [problems].
  String? joined(List<LineProblem> problems) {
    if (isEmpty) return null;
    final payloads = [
      for (var index = 1; index <= count; index++) payload(index, problems),
    ];
    return payloads.contains(null) ? null : payloads.join();
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
