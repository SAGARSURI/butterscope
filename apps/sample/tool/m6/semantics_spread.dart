/// Compares the same spans run with semantics on and with it off, over
/// several runs of each: each span's median and spread per metric (the M6
/// plan's Semantics section).
library;

import 'validity.dart';

/// The span metrics compared, as the report names them.
const List<String> comparedMetrics = [
  'hitchRatio',
  'jankyRate',
  'missedVsyncs',
];

/// One span's values of one metric over a set of runs.
final class Spread {
  /// Creates the spread of [values], which must not be empty.
  new(Iterable<double> values) : values = [...values]..sort();

  /// The values, smallest first.
  final List<double> values;

  /// The nearest-rank median: the smallest value with at least half of
  /// them at or below it, so the lower middle one of an even count.
  double get median => values[(values.length / 2).ceil() - 1];

  /// The largest value less the smallest.
  double get width => values.last - values.first;
}

/// Each span's [metric] over [reports], one decoded report per run, by
/// span name in the order the spans first appear. A run whose span lacks
/// the metric adds nothing for it.
Map<String, List<double>> spanValues(
  List<Map<String, Object?>> reports,
  String metric,
) {
  final values = <String, List<double>>{};
  for (final report in reports) {
    for (final part in partsOf(report)) {
      if (part case {
        'kind': 'span',
        'name': final String name,
        'metrics': final Map<String, Object?> metrics,
      }) {
        if (metrics[metric] case final num value) {
          (values[name] ??= []).add(value.toDouble());
        }
      }
    }
  }
  return values;
}

/// Why [json] cannot join the runs with semantics [on]: the run is void by
/// a guard outside [allow], a span is void by its own guard, a span's
/// semantics read otherwise at its start or end, or a part flags a rate
/// mismatch, since a screen held below its declared rate (the iPhone's
/// Limit Frame Rate) loses frames that would read as a semantics cost.
/// [allow] names guards that may void the run, such as `thermal` for M6's
/// iPhone runs at "fair" (void until decision record 0007); a void run
/// voids every span without a span reason (run_report.dart), so those
/// spans still count.
List<String> semanticsProblems(
  Map<String, Object?> json, {
  required bool on,
  Set<String> allow = const {},
}) {
  final runValid = json['valid'] == true;
  return [
    if (!runValid && runReasons(json).isEmpty)
      'The run is void with no reason given',
    for (final guard in runReasons(json))
      if (!allow.contains(guard)) 'The run is void: $guard',
    for (final part in partsOf(json))
      if (part['kind'] == 'span') ...[
        if (part['valid'] != true && (runValid || _hasReasons(part)))
          'Span ${part['name']} is void',
        if (!_reads(part['semantics'], on: on))
          'Span ${part['name']} read semantics ${part['semantics']}, not $on',
      ],
    for (final part in partsOf(json))
      if (mismatchesOf(part) case final slices when slices.isNotEmpty)
        '${part['kind']} ${part['name']} flags a rate mismatch: $slices',
  ];
}

/// [on] against [off] for [metric], as a Markdown table: each span's run
/// count, median and spread with semantics on and off.
String spreadTable(
  String metric,
  Map<String, List<double>> on,
  Map<String, List<double>> off,
) {
  String row(List<Object> cells) => '| ${cells.join(' | ')} |';
  List<Object> cells(List<double>? values) {
    if (values == null || values.isEmpty) return [0, '', ''];
    final spread = Spread(values);
    return [values.length, _fixed(spread.median), _fixed(spread.width)];
  }

  return [
    '#### $metric',
    '',
    row([
      'Span',
      'Runs on',
      'Median on',
      'Spread on',
      'Runs off',
      'Median off',
      'Spread off',
    ]),
    row(List.filled(7, '---')),
    for (final name in {...on.keys, ...off.keys})
      row([name, ...cells(on[name]), ...cells(off[name])]),
  ].join('\n');
}

/// Whether [semantics], a span's `[atStart, atEnd]`, reads [on] at both.
bool _reads(Object? semantics, {required bool on}) =>
    semantics is List &&
    semantics.length == 2 &&
    semantics.every((read) => read == on);

bool _hasReasons(Map<String, Object?> part) =>
    (part['reasons'] as List<Object?>? ?? const []).isNotEmpty;

String _fixed(double value) => value.toStringAsFixed(value < 1 ? 4 : 2);
