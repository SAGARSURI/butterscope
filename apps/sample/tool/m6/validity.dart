/// Checks an M6 report against what its run was set up to show: clean,
/// voided by one forced guard, or on a screen forced below its declared
/// rate. Each check returns its problems as messages for people, empty
/// when the report shows what it should.
library;

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
/// the one guard given.
List<String> notClean(
  Map<String, Object?> json, {
  Map<String, String> voidSpans = const {},
}) {
  return [
    for (final guard in runReasons(json)) 'The run is void: $guard',
    for (final part in partsOf(json)) ..._spanProblems(part, voidSpans),
    for (final part in partsOf(json))
      if (mismatchesOf(part) case final slices when slices.isNotEmpty)
        '${part['kind']} ${part['name']} flags a rate mismatch: $slices',
  ];
}

/// For a run forced to fail [guard]: the run is void by it alone.
List<String> notVoidedBy(Map<String, Object?> json, String guard) {
  final reasons = runReasons(json);
  return [
    if (!reasons.contains(guard)) 'The run is not void by $guard',
    for (final other in reasons)
      if (other != guard) 'The run is also void by $other',
  ];
}

/// For a screen forced below its declared rate: at least one part is
/// judged, and every part with a judged slice flags a mismatch.
List<String> notFlagged(Map<String, Object?> json) {
  final judged = [
    for (final part in partsOf(json))
      if (_slicesJudged(part) > 0) part,
  ];
  return [
    if (judged.isEmpty) 'No part had a slice to judge',
    for (final part in judged)
      if (mismatchesOf(part).isEmpty)
        '${part['kind']} ${part['name']} flags no mismatch',
  ];
}

Iterable<String> _spanProblems(
  Map<String, Object?> part,
  Map<String, String> voidSpans,
) sync* {
  if (part['kind'] != 'span') return;
  final name = part['name'];
  final reasons = _guards(part['reasons']);
  final expected = voidSpans[name];
  if (expected == null) {
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
