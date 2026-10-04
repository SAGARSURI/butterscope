import 'package:butterscope/butterscope.dart';

import 'bscope_log.dart';

/// The M2 checks for one logged window, as text for people.
///
/// Every metric comes from butterscope's M1 functions; this only lays them
/// out next to the window's own numbers.
String summariseWindow(LoggedWindow window) {
  final out = StringBuffer('== ${window.name}');
  final run = [
    for (final key in ['plant', 'semantics', 'mode'])
      if (window.fields[key] case final value?) '$key=$value',
  ];
  out.writeln(run.isEmpty ? '' : ' (${run.join(', ')})');

  for (final (key, count) in [
    ('rates', window.rateReads.length),
    ('samples', window.samples.length),
  ]) {
    final logged = window.intField(key);
    if (count != logged) {
      out.writeln(
        'WARNING: $count of $logged $key read; the numbers below are wrong.',
      );
    }
  }

  final reads = window.rateReads;
  if (reads.isEmpty || !FrameBudget.isValidRefreshRate(reads.first.hertz)) {
    out.writeln('No usable declared refresh rate; nothing to measure.');
    return out.toString();
  }
  final budget = FrameBudget(reads.first.hertz);
  final samples = window.samples;
  final metrics = WindowMetrics.of(samples, budget);
  final wallSeconds =
      window.intField('wallMicros') / Duration.microsecondsPerSecond;
  final expected = wallSeconds * budget.refreshRate;

  void row(String label, Object value) {
    out.writeln('  ${label.padRight(26)}$value');
  }

  row(
    'Frames vs expected',
    '${samples.length} vs ${expected.toStringAsFixed(1)} '
        '(${wallSeconds.toStringAsFixed(3)} s × '
        '${_hz(budget.refreshRate)}): '
        '${_signedPercent(samples.length / expected - 1)}',
  );
  row(
    'Declared rate reads',
    '${{for (final read in reads) _hz(read.hertz)}.join(', ')} '
        'over ${reads.length} reads',
  );
  row('Observed rate', _hz(metrics.observedRefreshRate));
  row('Frame-number gaps', _gaps(samples));
  final overheads = [for (final s in samples) s.vsyncOverheadMicros];
  row(
    'vsyncOverhead median, p99',
    overheads.isEmpty
        ? 'n/a'
        : '${nearestRankPercentile(overheads, 50)} µs, '
              '${nearestRankPercentile(overheads, 99)} µs',
  );
  row(
    'Missed vsyncs',
    '${metrics.missedVsyncCount} '
        '(${metrics.missedVsyncMillis.toStringAsFixed(1)} ms)',
  );
  row('Janky rate', _percent(metrics.jankyRate));
  row('p99 UI, raster', '${_b(metrics.uiP99)}, ${_b(metrics.rasterP99)}');
  row('Hitch ratio', '${_fixed(metrics.hitchRatio)} ms/s');
  row(
    'Flush',
    'timedOut=${window.fields['flushTimedOut']}, '
        '${window.intField('flushMicros')} µs',
  );
  final callbackMicros = window.intField('callbackMicros');
  row(
    'Recorder callback',
    wallSeconds == 0
        ? '$callbackMicros µs'
        : '${(callbackMicros / wallSeconds).toStringAsFixed(1)} µs/s',
  );
  return out.toString();
}

/// How many times the frame number skipped between consecutive samples,
/// and how many numbers were skipped in all.
String _gaps(List<FrameSample> samples) {
  var gaps = 0;
  var skipped = 0;
  for (var i = 1; i < samples.length; i++) {
    final step = samples[i].frameNumber - samples[i - 1].frameNumber;
    if (step != 1) {
      gaps++;
      skipped += step - 1;
    }
  }
  return '$gaps gaps, $skipped numbers skipped';
}

String _hz(double? hertz) =>
    hertz == null ? 'n/a' : '${hertz.toStringAsFixed(2)} Hz';

String _fixed(double? value) => value?.toStringAsFixed(2) ?? 'n/a';

String _b(double? multiple) =>
    multiple == null ? 'n/a' : '${_fixed(multiple)}B';

String _percent(double? share) =>
    share == null ? 'n/a' : '${(share * 100).toStringAsFixed(2)}%';

String _signedPercent(double share) =>
    '${share >= 0 ? '+' : ''}${(share * 100).toStringAsFixed(2)}%';
