import 'dart:math' as math;

import 'package:butterscope/butterscope.dart';

import 'bscope_log.dart';

/// Declared reads further apart than this share of the first change `B`
/// (DESIGN 7.2, decision record 0001 item 6).
const double _rateTolerance = 0.05;

/// The M2 checks for every run and window in [log], as text for people.
String summariseLog(BscopeLog log) {
  final out = StringBuffer();
  for (final (index, run) in log.runs.indexed) {
    if (log.runs.length > 1) out.writeln('#### Run ${index + 1}');
    run.windows.map(summariseWindow).forEach(out.writeln);
    if (run.problems.isEmpty) {
      out.writeln('Every line is present.');
    } else {
      run.problems.forEach(out.writeln);
    }
  }
  log.problems.forEach(out.writeln);
  return out.toString();
}

/// The M2 checks for one logged window, as text for people.
///
/// Every metric comes from butterscope's M1 functions; this only lays them
/// out next to the window's own numbers. A window whose declared rate
/// changed is `INVALID`: it gets its raw counts and observed rate per
/// one-second slice, but no metric that needs one budget.
String summariseWindow(LoggedWindow window) {
  final out = StringBuffer('== ${window.name}');
  final run = [
    for (final key in ['plant', 'semantics', 'mode'])
      if (window.fields[key] case final value?) '$key=$value',
  ];
  out.writeln(run.isEmpty ? '' : ' (${run.join(', ')})');
  _writeWarnings(out, window);

  final reads = window.rateReads;
  if (reads.isEmpty || !FrameBudget.isValidRefreshRate(reads.first.hertz)) {
    out.writeln('No usable declared refresh rate; nothing to measure.');
    return out.toString();
  }
  final change = _rateChange(reads);
  if (change != null) {
    out.writeln(
      'INVALID: declared rate changed (${_hz(reads.first.hertz)} -> '
      '${_hz(change.hertz)} after sample ${change.afterSamples})',
    );
    _writeChangedRate(out, window);
  } else {
    _writeMetrics(out, window, FrameBudget(reads.first.hertz));
  }
  return out.toString();
}

void _writeWarnings(StringBuffer out, LoggedWindow window) {
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
  if (window.fields['flushTimedOut'] == 'true') {
    out.writeln(
      'INCOMPLETE: flush timed out; frames at the end may be missing.',
    );
  }
}

/// The first read more than 5% away from the first one, if any.
RefreshRateRead? _rateChange(List<RefreshRateRead> reads) {
  final first = reads.first.hertz;
  for (final read in reads.skip(1)) {
    if ((read.hertz / first - 1).abs() > _rateTolerance) return read;
  }
  return null;
}

void _row(StringBuffer out, String label, Object value) {
  out.writeln('  ${label.padRight(26)}$value');
}

double _wallSeconds(LoggedWindow window) {
  return window.intField('wallMicros') / Duration.microsecondsPerSecond;
}

void _writeMetrics(StringBuffer out, LoggedWindow window, FrameBudget budget) {
  final samples = window.samples;
  final metrics = WindowMetrics.of(samples, budget);
  final wallSeconds = _wallSeconds(window);
  final expected = wallSeconds * budget.refreshRate;
  _row(
    out,
    'Frames vs expected',
    '${samples.length} vs ${expected.toStringAsFixed(1)} '
        '(${wallSeconds.toStringAsFixed(3)} s × '
        '${_hz(budget.refreshRate)}): '
        '${_signedPercent(samples.length / expected - 1)}',
  );
  _writeReads(out, window);
  _row(out, 'Observed rate', _hz(metrics.observedRefreshRate));
  _writeRaw(out, window);
  _row(
    out,
    'Missed vsyncs',
    '${metrics.missedVsyncCount} '
        '(${metrics.missedVsyncMillis.toStringAsFixed(1)} ms)',
  );
  _row(out, 'Janky rate', _percent(metrics.jankyRate));
  _row(out, 'p99 UI, raster', '${_b(metrics.uiP99)}, ${_b(metrics.rasterP99)}');
  _row(out, 'Hitch ratio', '${_fixed(metrics.hitchRatio)} ms/s');
  _writeCost(out, window);
}

void _writeChangedRate(StringBuffer out, LoggedWindow window) {
  final samples = window.samples;
  final expected = _integratedExpected(window);
  _row(
    out,
    'Frames vs declared reads',
    '${samples.length} vs ${expected.toStringAsFixed(1)} '
        '(${_wallSeconds(window).toStringAsFixed(3)} s, each read until the '
        'next): ${_signedPercent(samples.length / expected - 1)}',
  );
  _writeReads(out, window);
  _writeRaw(out, window);
  final slices = _observedBySlice(window);
  for (final (index, (declared, observed)) in slices.indexed) {
    _row(
      out,
      'Slice ${index + 1} s observed',
      '${_hz(observed)} (declared ${_hz(declared)})',
    );
  }
  _writeCost(out, window);
}

void _writeReads(StringBuffer out, LoggedWindow window) {
  final reads = window.rateReads;
  _row(
    out,
    'Declared rate reads',
    '${{for (final read in reads) _hz(read.hertz)}.join(', ')} '
        'over ${reads.length} reads',
  );
}

/// Counts that need no budget.
void _writeRaw(StringBuffer out, LoggedWindow window) {
  final samples = window.samples;
  _row(out, 'Frame-number gaps', _gaps(samples));
  final overheads = [for (final s in samples) s.vsyncOverheadMicros];
  _row(
    out,
    'vsyncOverhead median, p99',
    overheads.isEmpty
        ? 'n/a'
        : '${nearestRankPercentile(overheads, 50)} µs, '
              '${nearestRankPercentile(overheads, 99)} µs',
  );
}

void _writeCost(StringBuffer out, LoggedWindow window) {
  _row(
    out,
    'Flush',
    'timedOut=${window.fields['flushTimedOut']}, '
        '${window.intField('flushMicros')} µs',
  );
  final callbackMicros = window.intField('callbackMicros');
  final wallSeconds = _wallSeconds(window);
  _row(
    out,
    'Recorder callback',
    wallSeconds == 0
        ? '$callbackMicros µs'
        : '${(callbackMicros / wallSeconds).toStringAsFixed(1)} µs/s',
  );
}

/// When each declared read was taken, in vsync microseconds: at the vsync
/// of the last sample reported before it, or at the first sample's vsync
/// for reads before any sample.
List<int> _readTimes(LoggedWindow window) {
  final samples = window.samples;
  final start = samples.first.vsyncStartMicros;
  int timeOf(RefreshRateRead read) {
    final after = math.min(read.afterSamples, samples.length);
    return after == 0 ? start : samples[after - 1].vsyncStartMicros;
  }

  return [for (final read in window.rateReads) timeOf(read)];
}

/// The frames the declared reads predict: each read's rate times the time
/// until the next read, the last until the window's end.
double _integratedExpected(LoggedWindow window) {
  final reads = window.rateReads;
  if (window.samples.isEmpty) return _wallSeconds(window) * reads.first.hertz;
  final times = _readTimes(window);
  final end = times.first + window.intField('wallMicros');
  var frames = 0.0;
  for (var i = 0; i < reads.length; i++) {
    final until = i + 1 < reads.length ? times[i + 1] : end;
    final span = math.min(until, end) - times[i];
    if (span > 0) {
      frames += reads[i].hertz * span / Duration.microsecondsPerSecond;
    }
  }
  return frames;
}

/// The declared rate in effect at the start of each one-second slice, and
/// the rate observed from the slice's frames.
List<(double, double?)> _observedBySlice(LoggedWindow window) {
  final samples = window.samples;
  if (samples.isEmpty) return const [];
  final times = _readTimes(window);
  final start = samples.first.vsyncStartMicros;
  final slices = <int, List<FrameSample>>{};
  for (final sample in samples) {
    final index = (sample.vsyncStartMicros - start) ~/ 1000000;
    (slices[index] ??= []).add(sample);
  }
  return [
    for (final MapEntry(key: index, value: frames) in slices.entries)
      () {
        final sliceStart = start + index * 1000000;
        var declared = window.rateReads.first.hertz;
        for (var i = 0; i < times.length; i++) {
          if (times[i] <= sliceStart) declared = window.rateReads[i].hertz;
        }
        final budget = FrameBudget(declared);
        return (declared, observeRefreshRate(frames, budget));
      }(),
  ];
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
