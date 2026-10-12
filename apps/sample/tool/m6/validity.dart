/// Checks an M6 report against what its run was set up to show: clean,
/// voided by one forced guard, or on a screen forced below its declared
/// rate. Each check returns its problems as messages for people, empty
/// when the report shows what it should.
library;

import '../m5/report_log.dart' show flushTimedOut;

/// The guards that voided the run, by name.
List<String> runReasons(Map<String, Object?> json) => _guards(json['reasons']);

/// The parts of [json], such as tests, spans and episodes, as maps.
List<Map<String, Object?>> partsOf(Map<String, Object?> json) {
  final list = json['parts'] as List<Object?>? ?? const [];
  return [for (final part in list) part! as Map<String, Object?>];
}

/// The rate mismatches a part flags, as `[second, gaps, observedHz]`.
List<List<Object?>> mismatchesOf(Map<String, Object?> part) {
  final metrics = part['metrics'] as Map<String, Object?>?;
  final list = metrics?['rateMismatches'] as List<Object?>? ?? const [];
  return [for (final slice in list) slice! as List<Object?>];
}

/// For a clean run: the run and every span are valid, and no part flags a
/// rate mismatch. [voidSpans] names spans that should be void, each by
/// the one guard given; each must be in the report. [allow] names guards
/// that may void the run on top of what it was set up to show, such as
/// `thermal` for M6's iPhone runs at "fair", which voided a run until
/// decision record 0007.
List<String> notClean(
  Map<String, Object?> json, {
  Map<String, String> voidSpans = const {},
  Set<String> allow = const {},
}) {
  final spans = {
    for (final part in partsOf(json))
      if (part['kind'] == 'span') part['name'],
  };
  return [
    ..._runProblems(json, allow),
    for (final name in voidSpans.keys)
      if (!spans.contains(name)) 'Span $name is not in the report',
    for (final part in partsOf(json))
      ..._spanProblems(part, voidSpans, runValid: json['valid'] == true),
    for (final part in partsOf(json))
      if (mismatchesOf(part) case final slices when slices.isNotEmpty)
        '${part['kind']} ${part['name']} flags a rate mismatch: $slices',
  ];
}

/// For a run forced to fail [guard]: the run is void by it, and by no
/// other guard but those in [allow].
List<String> notVoidedBy(
  Map<String, Object?> json,
  String guard, {
  Set<String> allow = const {},
}) {
  return [
    if (!runReasons(json).contains(guard)) 'The run is not void by $guard',
    ..._runProblems(json, {...allow, guard}),
  ];
}

/// The [incomplete] problems a run set up to show [expect] should not
/// have: all of them, but for a timed-out flush in a run forced to leave
/// the frame policy. Off `benchmarkLive`, the frame the recording ends on
/// can wait for a timing until the flush gives up, as on the S24 on
/// 2026-10-11; that run is void whatever its frames say.
List<String> unexpectedIncomplete(List<String> incomplete, String expect) {
  return [
    for (final problem in incomplete)
      if (expect != 'framePolicy' || problem != flushTimedOut) problem,
  ];
}

/// For a screen forced below its declared rate: no guard but those in
/// [allow] voids the run, at least one part is judged, and every part
/// with a judged slice flags a mismatch. Low Power Mode also caps the
/// iPhone at 60 Hz, so a run void by it does not count as flagged.
List<String> notFlagged(
  Map<String, Object?> json, {
  Set<String> allow = const {},
}) {
  final judged = [
    for (final part in partsOf(json))
      if (_slicesJudged(part) > 0) part,
  ];
  return [
    ..._runProblems(json, allow),
    if (judged.isEmpty) 'No part had a slice to judge',
    for (final part in judged)
      if (mismatchesOf(part).isEmpty)
        '${part['kind']} ${part['name']} flags no mismatch',
  ];
}

/// The run's guards outside [allow], and a run marked void with no guard
/// named.
List<String> _runProblems(Map<String, Object?> json, Set<String> allow) {
  final reasons = runReasons(json);
  return [
    if (json['valid'] != true && reasons.isEmpty)
      'The run is void with no reason given',
    for (final guard in reasons)
      if (!allow.contains(guard)) 'The run is void: $guard',
  ];
}

Iterable<String> _spanProblems(
  Map<String, Object?> part,
  Map<String, String> voidSpans, {
  required bool runValid,
}) sync* {
  if (part['kind'] != 'span') return;
  final name = part['name'];
  final reasons = _guards(part['reasons']);
  final expected = voidSpans[name];
  if (expected == null) {
    // A void run voids every span without naming a span reason
    // (run_report.dart), so only a valid run leaves this unexplained.
    if (runValid && part['valid'] == false && reasons.isEmpty) {
      yield 'Span $name is void with no reason given';
    }
    for (final guard in reasons) {
      yield 'Span $name is void: $guard';
    }
  } else if (reasons.length != 1 || reasons.single != expected) {
    yield 'Span $name should be void by $expected alone, not $reasons';
  }
}

int _slicesJudged(Map<String, Object?> part) {
  final metrics = part['metrics'] as Map<String, Object?>?;
  return metrics?['rateSlicesJudged'] as int? ?? 0;
}

List<String> _guards(Object? reasons) {
  final list = reasons as List<Object?>? ?? const [];
  return [
    for (final reason in list) (reason! as List<Object?>).first! as String,
  ];
}
