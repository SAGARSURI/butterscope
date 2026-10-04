import 'package:flutter_test/flutter_test.dart';

import '../tool/m2/bscope_log.dart';
import '../tool/m2/window_summary.dart';

/// The lines the probe test prints for a window of [count] frames 8333 µs
/// apart at 120 Hz over [wallMicros], numbered from 11, with each number in
/// [skip] left out, followed by the done line. [rates] replaces the two
/// 120 Hz rate reads.
List<String> logOf(
  int count, {
  Set<int> skip = const {},
  List<String>? rates,
  int wallMicros = 1000000,
  bool flushTimedOut = false,
}) {
  final numbers = [
    for (var n = 11; n <= 10 + count; n++)
      if (!skip.contains(n)) n,
  ];
  final frames = [
    for (final n in numbers) '$n:${n * 8333}:2000:3000:${100 + n}',
  ];
  final reads = rates ?? ['120.0:0', '120.0:${numbers.length}'];
  final bodies = [
    'run policy=benchmarkLive plant=none semantics=off mode=profile',
    [
      'window animated plant=none semantics=off mode=profile',
      'wallMicros=$wallMicros start=10 end=${10 + count}',
      'flushTimedOut=$flushTimedOut flushMicros=900 callbackMicros=50',
      'rates=${reads.length}',
      'samples=${numbers.length}',
    ].join(' '),
    'rates animated ${reads.join(' ')}',
    for (var i = 0; i < frames.length; i += 20)
      'frames animated ${frames.skip(i).take(20).join(' ')}',
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

      final window = log.runs.single.windows.single;
      expect(log.runs.single.problems, isEmpty);
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
      expect(log.runs.single.problems, isEmpty);
      expect(log.runs.single.windows.single.samples, hasLength(2));
    });

    test('keeps one copy of a repeated line', () {
      final lines = logOf(2);
      final log = readBscopeLog([...lines, lines[3]].join('\n'));

      expect(log.runs.single.windows.single.samples, hasLength(2));
    });

    test('reports a missing line', () {
      final lines = logOf(3)..removeAt(3);
      final log = readBscopeLog(lines.join('\n'));

      expect(log.runs.single.problems, ['Line 4 is missing.']);
    });

    test('reports a log with no done line', () {
      final lines = logOf(1)..removeLast();
      final log = readBscopeLog(lines.join('\n'));

      expect(log.runs.single.problems.single, contains('No "done" line'));
    });

    test('reports a frame line for a window with no header', () {
      final lines = logOf(1)..removeAt(1);
      final log = readBscopeLog(lines.join('\n'));

      expect(log.runs.single.problems, contains('Line 2 is missing.'));
      expect(
        log.runs.single.problems,
        contains('Line 3: no header for window "animated"'),
      );
    });

    test('splits a log holding two runs', () {
      final log = readBscopeLog([...logOf(3), ...logOf(5)].join('\n'));

      expect(log.runs, hasLength(2));
      expect(log.runs.first.windows.single.samples, hasLength(3));
      expect(log.runs.last.windows.single.samples, hasLength(5));
      expect(log.runs.last.problems, isEmpty);
    });

    test('splits runs where the numbering restarts', () {
      // The second run's run line was dropped, so only its numbers show it.
      final second = logOf(5)..removeAt(0);
      final log = readBscopeLog([...logOf(3), ...second].join('\n'));

      expect(log.runs, hasLength(2));
      expect(log.runs.last.windows.single.samples, hasLength(5));
      expect(log.runs.last.problems, ['Line 1 is missing.']);
    });

    test('reports a malformed entry and keeps the rest', () {
      final lines = logOf(3);
      lines[3] = lines[3].replaceFirst(RegExp('12:[^ ]*'), '12:abc:1');
      final log = readBscopeLog(lines.join('\n'));

      final run = log.runs.single;
      expect(run.problems, ['Line 4: unreadable frames entry "12:abc:1"']);
      final numbers = [
        for (final s in run.windows.single.samples) s.frameNumber,
      ];
      expect(numbers, [11, 13]);
    });

    test('reports an unreadable line', () {
      final log = readBscopeLog([...logOf(1), 'BSCOPE x'].join('\n'));

      expect(log.problems, ['Unreadable line: BSCOPE x']);
    });
  });

  group('summariseWindow', () {
    LoggedWindow logged(
      int count, {
      Set<int> skip = const {},
      List<String>? rates,
      int wallMicros = 1000000,
      bool flushTimedOut = false,
    }) {
      final lines = logOf(
        count,
        skip: skip,
        rates: rates,
        wallMicros: wallMicros,
        flushTimedOut: flushTimedOut,
      );
      return readBscopeLog(lines.join('\n')).runs.single.windows.single;
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

    test('warns when fewer samples were read than were written', () {
      // 25 frames take two frame lines; drop the second.
      final lines = logOf(25)..removeAt(4);
      final window = readBscopeLog(lines.join('\n')).runs.single.windows.single;
      expect(summariseWindow(window), contains('20 of 25 samples read'));
    });

    test('flags a window whose flush timed out as incomplete', () {
      final summary = summariseWindow(logged(3, flushTimedOut: true));
      expect(summary, contains('INCOMPLETE: flush timed out'));
    });

    test('marks a window whose declared rate changed as invalid', () {
      // 240 frames 8333 µs apart over 2 s. The screen declares 60 Hz from
      // sample 120 on, so the reads predict about 120 + 60 frames.
      final window = logged(
        240,
        rates: ['120.0:0', '60.0:120', '60.0:240'],
        wallMicros: 2000000,
      );
      final summary = summariseWindow(window);
      expect(
        summary,
        contains(
          'INVALID: declared rate changed (120.00 Hz -> 60.00 Hz '
          'after sample 120)',
        ),
      );
      expect(summary, contains('Frames vs declared reads  240 vs 179.5'));
      expect(summary, contains('Slice 1 s observed'));
      expect(summary, isNot(contains('Janky rate')));
      expect(summary, isNot(contains('Hitch ratio')));
    });

    test('keeps a rate change within 5% valid', () {
      final summary = summariseWindow(logged(3, rates: ['120.0:0', '115.0:3']));
      expect(summary, isNot(contains('INVALID')));
      expect(summary, contains('Janky rate'));
    });

    test('gives the recorder cost per second of window', () {
      // 50 µs over a 1 s window.
      expect(summariseWindow(logged(3)), contains('50.0 µs/s'));
    });
  });
}
