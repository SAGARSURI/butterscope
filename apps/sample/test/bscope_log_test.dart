import 'package:flutter_test/flutter_test.dart';

import '../tool/m2/bscope_log.dart';
import '../tool/m2/window_summary.dart';

/// The lines the probe test prints for a window of [count] frames 8333 µs
/// apart at 120 Hz over 1 s, numbered from 11, with each number in [skip]
/// left out, followed by the done line.
List<String> logOf(int count, {Set<int> skip = const {}}) {
  final numbers = [
    for (var n = 11; n <= 10 + count; n++)
      if (!skip.contains(n)) n,
  ];
  final bodies = [
    'run policy=benchmarkLive plant=none semantics=off mode=profile',
    [
      'window animated plant=none semantics=off mode=profile',
      'wallMicros=1000000 start=10 end=${10 + count} flushTimedOut=false',
      'flushMicros=900 callbackMicros=50 samples=${numbers.length}',
    ].join(' '),
    'rate animated 120.0 0',
    for (final n in numbers)
      'frame animated $n ${n * 8333} 2000 3000 ${100 + n}',
    'rate animated 120.0 ${numbers.length}',
    'metrics animated frames=${numbers.length}',
  ];
  return [
    for (var i = 0; i < bodies.length; i++) 'BSCOPE ${i + 1} ${bodies[i]}',
    'BSCOPE ${bodies.length + 1} done ${bodies.length + 1}',
  ];
}

void main() {
  group('readBscopeLog', () {
    test('reads the header, rate reads and samples of a window', () {
      final log = readBscopeLog(logOf(3).join('\n'));

      final window = log.windows.single;
      expect(log.problems, isEmpty);
      expect(window.name, 'animated');
      expect(window.fields['plant'], 'none');
      expect(window.intField('end'), 13);
      expect([for (final s in window.samples) s.frameNumber], [11, 12, 13]);
      final last = window.samples.last;
      expect(last.vsyncStartMicros, 13 * 8333);
      expect(last.buildMicros, 2000);
      expect(last.rasterMicros, 3000);
      expect(last.vsyncOverheadMicros, 113);
      expect([for (final r in window.rateReads) r.afterSamples], [0, 3]);
      expect([for (final r in window.rateReads) r.hertz], [120, 120]);
    });

    test('ignores what logcat and flutter drive put before the tag', () {
      final lines = logOf(2);
      final text = [
        'I/flutter (12345): ${lines[0]}',
        'flutter: ${lines[1]}',
        ...lines.skip(2),
        'D/OtherTag: unrelated',
      ].join('\n');

      final log = readBscopeLog(text);
      expect(log.problems, isEmpty);
      expect(log.windows.single.samples, hasLength(2));
    });

    test('keeps one copy of a repeated line', () {
      final lines = logOf(2);
      final log = readBscopeLog([...lines, lines[3]].join('\n'));

      expect(log.windows.single.samples, hasLength(2));
    });

    test('reports a missing line', () {
      final lines = logOf(3)..removeAt(4);
      final log = readBscopeLog(lines.join('\n'));

      expect(log.problems, ['Line 5 is missing.']);
    });

    test('reports a log with no done line', () {
      final lines = logOf(1)..removeLast();
      final log = readBscopeLog(lines.join('\n'));

      expect(log.problems.single, contains('No "done" line'));
    });

    test('reports a frame line for a window with no header', () {
      final lines = logOf(1)..removeAt(1);
      final log = readBscopeLog(lines.join('\n'));

      expect(log.problems, contains('Line 2 is missing.'));
      expect(log.problems, contains('Line 3: no header for window "animated"'));
    });

    test('reports an unreadable line', () {
      final log = readBscopeLog([...logOf(1), 'BSCOPE x'].join('\n'));

      expect(log.problems, ['Unreadable line: BSCOPE x']);
    });
  });

  group('summariseWindow', () {
    LoggedWindow logged(int count, {Set<int> skip = const {}}) {
      final lines = logOf(count, skip: skip);
      return readBscopeLog(lines.join('\n')).windows.single;
    }

    test('compares the frame count with wall-clock length × rate', () {
      // 1 s at 120 Hz expects 120 frames; 114 is 5% short.
      final summary = summariseWindow(logged(114));
      expect(summary, contains('114 vs 120.0'));
      expect(summary, contains('-5.00%'));
    });

    test('counts frame-number gaps and the numbers skipped', () {
      final summary = summariseWindow(logged(10, skip: {13, 16, 17}));
      expect(summary, contains('2 gaps, 3 numbers skipped'));
    });

    test('gives the recorder cost per second of window', () {
      // 50 µs over a 1 s window.
      expect(summariseWindow(logged(3)), contains('50.0 µs/s'));
    });
  });
}
