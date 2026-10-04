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

/// What a log held.
class BscopeLog {
  new(this.windows, this.problems);

  /// The windows, in the order their headers were written.
  final List<LoggedWindow> windows;

  /// Missing, repeated or unreadable lines, as messages for people.
  final List<String> problems;
}

/// Reads every `BSCOPE` line in [text], a raw logcat dump or a
/// `flutter drive` transcript, whatever comes before the tag on each line.
BscopeLog readBscopeLog(String text) {
  final lines = <int, List<String>>{};
  final problems = <String>[];
  for (final raw in text.split('\n')) {
    final at = raw.indexOf('$bscopeTag ');
    if (at < 0) continue;
    final words = raw.substring(at).trim().split(' ');
    final seq = words.length > 2 ? int.tryParse(words[1]) : null;
    if (seq == null) {
      problems.add('Unreadable line: ${raw.trim()}');
    } else {
      lines.putIfAbsent(seq, () => words.sublist(2));
    }
  }
  problems.addAll(_missing(lines));

  final windows = <String, LoggedWindow>{};
  final sorted = lines.keys.toList()..sort();
  for (final seq in sorted) {
    final words = lines[seq]!;
    final problem = _apply(words, windows);
    if (problem != null) problems.add('Line $seq: $problem');
  }
  return BscopeLog(windows.values.toList(), problems);
}

Iterable<String> _missing(Map<int, List<String>> lines) sync* {
  final done = lines.values.where((words) => words.first == 'done');
  if (done.isEmpty) {
    yield 'No "done" line: the log may be cut short.';
    return;
  }
  final count = int.parse(done.first[1]);
  for (var seq = 1; seq <= count; seq++) {
    if (!lines.containsKey(seq)) yield 'Line $seq is missing.';
  }
}

String? _apply(List<String> words, Map<String, LoggedWindow> windows) {
  final kind = words.first;
  if (kind == 'run' || kind == 'done' || kind == 'metrics') return null;
  if (words.length < 2) return 'too short';
  final name = words[1];
  if (kind == 'window') {
    final window = windows[name] = LoggedWindow(name);
    for (final field in words.skip(2)) {
      if (field.split('=') case [final key, final value]) {
        window.fields[key] = value;
      }
    }
    return null;
  }
  final window = windows[name];
  if (window == null) return 'no header for window "$name"';
  for (final entry in words.skip(2)) {
    final numbers = entry.split(':').map(num.parse).toList();
    switch (kind) {
      case 'rates':
        window.rateReads.add(
          RefreshRateRead(
            hertz: numbers[0].toDouble(),
            afterSamples: numbers[1].toInt(),
          ),
        );
      case 'frames':
        window.samples.add(
          FrameSample(
            frameNumber: numbers[0].toInt(),
            vsyncStartMicros: numbers[1].toInt(),
            buildMicros: numbers[2].toInt(),
            rasterMicros: numbers[3].toInt(),
            vsyncOverheadMicros: numbers[4].toInt(),
          ),
        );
      default:
        return 'unknown kind "$kind"';
    }
  }
  return null;
}
