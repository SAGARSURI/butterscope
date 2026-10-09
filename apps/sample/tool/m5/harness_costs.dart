/// Reads what `integration_test/m5_harness_test.dart` measures: each test
/// step's own time per call, and the frames its span lost, over a phone's
/// runs (the plan's Harness cost section).
library;

import 'dart:convert';

/// The tag each line of call times starts with.
const String harnessTag = 'BSCOPE-HARNESS';

/// Each span's call times in µs, from the [harnessTag] lines in [log].
///
/// A line can appear twice in a log, from the `flutter drive` transcript
/// and from logcat; the second copy replaces the first.
Map<String, List<int>> readCallTimes(String log) {
  final pattern = RegExp('$harnessTag (.+) ([0-9,]+)\$');
  return {
    for (final line in const LineSplitter().convert(log))
      if (pattern.firstMatch(line) case final match?)
        match.group(1)!: [
          for (final micros in match.group(2)!.split(',')) int.parse(micros),
        ],
  };
}

/// One span's cost over a phone's runs.
final class SpanCost {
  /// Creates the cost of the span [name].
  const new(this.name, this.callMicros, this.janky, this.missedVsyncs);

  /// The span's name, such as `still: tap`.
  final String name;

  /// Every call's time in µs, over all runs; empty for an empty span.
  final List<int> callMicros;

  /// The span's janky frames in each run.
  final List<int> janky;

  /// The span's missed vsyncs in each run.
  final List<int> missedVsyncs;
}

/// The cost of each span in [reports], one decoded report per run, in the
/// first run's order, with the call times [calls] from all the runs' logs.
List<SpanCost> spanCosts(
  List<Map<String, Object?>> reports,
  Map<String, List<int>> calls,
) {
  final runs = [for (final report in reports) _spanMetrics(report)];
  return [
    for (final name in runs.first.keys)
      SpanCost(
        name,
        calls[name] ?? const [],
        [for (final run in runs) run[name]?['janky'] as int? ?? 0],
        [for (final run in runs) run[name]?['missedVsyncs'] as int? ?? 0],
      ),
  ];
}

Map<String, Map<String, Object?>> _spanMetrics(Map<String, Object?> json) {
  final parts = (json['parts']! as List<Object?>).cast<Map<String, Object?>>();
  return {
    for (final part in parts)
      if (part['kind'] == 'span')
        part['name']! as String:
            part['metrics'] as Map<String, Object?>? ?? const {},
  };
}

/// The nearest-rank [percent] percentile of [values], or null when there
/// are none: the smallest value with at least [percent] % of them at or
/// below it.
int? percentile(List<int> values, int percent) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final rank = (sorted.length * percent / 100).ceil();
  return sorted[rank < 1 ? 0 : rank - 1];
}

/// [costs] as a Markdown table: call times in ms, and frames lost in each
/// run.
String costTable(List<SpanCost> costs) {
  String ms(int? micros) =>
      micros == null ? '' : (micros / 1000).toStringAsFixed(2);
  String row(List<Object> cells) => '| ${cells.join(' | ')} |';
  return [
    row([
      'Span',
      'Calls',
      'Median ms',
      'p90 ms',
      'Max ms',
      'Janky frames per run',
      'Missed vsyncs per run',
    ]),
    row(List.filled(7, '---')),
    for (final cost in costs)
      row([
        cost.name,
        cost.callMicros.length,
        ms(percentile(cost.callMicros, 50)),
        ms(percentile(cost.callMicros, 90)),
        ms(percentile(cost.callMicros, 100)),
        cost.janky.join(' '),
        cost.missedVsyncs.join(' '),
      ]),
  ].join('\n');
}
