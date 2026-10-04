/// Reads M2's throwaway log format for recorded windows.
///
/// The probe test prints each window as numbered lines that start with
/// `BSCOPE`, short enough that logcat does not truncate them (see
/// `integration_test/bscope_writer.dart`). The summariser reads them back
/// from a saved log. M7 replaces this with the report schema.
library;

import 'package:butterscope/butterscope.dart';

/// The tag every line starts with.
const String bscopeTag = 'BSCOPE';

/// One window read back from a log.
class LoggedWindow {
  new(this.name);

  final String name;

  /// The header's `key=value` fields.
  final Map<String, String> fields = {};

  final List<RefreshRateRead> rateReads = [];
  final List<FrameSample> samples = [];

  int intField(String key) => int.parse(fields[key] ?? '0');
}

/// One run of the probe test, from its `run` line to its `done` line.
class BscopeRun {
  /// The `key=value` fields of the run line.
  final Map<String, String> fields = {};

  /// The windows, in the order their headers were written.
  final List<LoggedWindow> windows = [];

  /// Missing or unreadable lines and entries, as messages for people.
  final List<String> problems = [];
}

/// What a log held.
class BscopeLog {
  new(this.runs, this.problems);

  /// The runs, in the order they appear in the log.
  final List<BscopeRun> runs;

  /// Lines that belong to no run, as messages for people.
  final List<String> problems;
}

/// Reads every `BSCOPE` line in [text], a raw logcat dump or a
/// `flutter drive` transcript, whatever comes before the tag on each line.
///
/// A log can hold several runs. A new run starts at a `run` line once the
/// current run has one, and wherever a line number comes back with
/// different content, which means the numbering started again. A line
/// repeated word for word is kept once; run lines carry a unique `id`, so
/// two runs never print the same one.
BscopeLog readBscopeLog(String text) {
  final runs = <Map<int, List<String>>>[];
  final problems = <String>[];
  for (final raw in text.split('\n')) {
    final at = raw.indexOf('$bscopeTag ');
    if (at < 0) continue;
    final words = raw.substring(at).trim().split(' ');
    final seq = words.length > 2 ? int.tryParse(words[1]) : null;
    if (seq == null) {
      problems.add('Unreadable line: ${raw.trim()}');
      continue;
    }
    final body = words.sublist(2);
    if (runs.isEmpty || _startsRun(runs.last, seq, body)) runs.add({});
    runs.last.putIfAbsent(seq, () => body);
  }
  return BscopeLog([for (final lines in runs) _readRun(lines)], problems);
}

bool _startsRun(Map<int, List<String>> run, int seq, List<String> body) {
  final seen = run[seq];
  // The same line twice is one line; a different line under the same
  // number means the numbering started again. Every run line carries a
  // unique id, so two runs' run lines never match.
  if (seen != null) return seen.join(' ') != body.join(' ');
  return body.first == 'run' && run.values.any((b) => b.first == 'run');
}

BscopeRun _readRun(Map<int, List<String>> lines) {
  final run = BscopeRun();
  run.problems.addAll(_missing(lines));
  final windows = <String, LoggedWindow>{};
  final sorted = lines.keys.toList()..sort();
  for (final seq in sorted) {
    final words = lines[seq]!;
    if (words.first == 'run') _readFields(words.skip(1), run.fields);
    for (final problem in _apply(words, windows)) {
      run.problems.add('Line $seq: $problem');
    }
  }
  run.windows.addAll(windows.values);
  return run;
}

Iterable<String> _missing(Map<int, List<String>> lines) sync* {
  final done = lines.values.where((words) => words.first == 'done');
  final count = done.isEmpty ? null : int.tryParse(done.first.last);
  if (count == null) {
    yield 'No "done" line: the log may be cut short.';
    return;
  }
  for (var seq = 1; seq <= count; seq++) {
    if (!lines.containsKey(seq)) yield 'Line $seq is missing.';
  }
}

void _readFields(Iterable<String> words, Map<String, String> fields) {
  for (final field in words) {
    if (field.split('=') case [final key, final value]) fields[key] = value;
  }
}

/// Applies one line to [windows], and returns its problems.
List<String> _apply(List<String> words, Map<String, LoggedWindow> windows) {
  final kind = words.first;
  if (kind == 'run' || kind == 'done' || kind == 'metrics') return const [];
  if (words.length < 2) return const ['too short'];
  final name = words[1];
  if (kind == 'window') {
    _readFields(words.skip(2), (windows[name] = LoggedWindow(name)).fields);
    return const [];
  }
  final window = windows[name];
  if (window == null) return ['no header for window "$name"'];
  final read = switch (kind) {
    'rates' => _readRate,
    'frames' => _readFrame,
    _ => null,
  };
  if (read == null) return ['unknown kind "$kind"'];
  return [
    for (final entry in words.skip(2))
      if (!read(entry, window)) 'unreadable $kind entry "$entry"',
  ];
}

/// Adds a rate read written as `hertz:afterSamples`; false if malformed.
bool _readRate(String entry, LoggedWindow window) {
  final parts = entry.split(':');
  if (parts.length != 2) return false;
  final hertz = double.tryParse(parts[0]);
  final after = int.tryParse(parts[1]);
  if (hertz == null || after == null) return false;
  window.rateReads.add(RefreshRateRead(hertz: hertz, afterSamples: after));
  return true;
}

/// Adds a sample written as `frameNumber:vsyncStart:build:raster:overhead`;
/// false if malformed.
bool _readFrame(String entry, LoggedWindow window) {
  final numbers = entry.split(':').map(int.tryParse).toList();
  if (numbers.length != 5 || numbers.contains(null)) return false;
  window.samples.add(
    FrameSample(
      frameNumber: numbers[0]!,
      vsyncStartMicros: numbers[1]!,
      buildMicros: numbers[2]!,
      rasterMicros: numbers[3]!,
      vsyncOverheadMicros: numbers[4]!,
    ),
  );
  return true;
}
