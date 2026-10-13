import 'package:meta/meta.dart';

/// The report schema this package reads and checks.
const int schemaVersion = 1;

/// What each number of a frame row is, in order: the engine's frame
/// number, its times in µs, then the raster cache's contents.
const List<String> frameFields = [
  'frame',
  'vsyncStartUs',
  'vsyncOverheadUs',
  'buildUs',
  'rasterUs',
  'totalSpanUs',
  'cacheLayers',
  'cacheLayerBytes',
  'cachePictures',
  'cachePictureBytes',
];

/// The guards a report may name, frozen with schema v1
/// (`docs/DESIGN.md` section 7.2).
const Set<String> guardNames = {
  'buildMode',
  'framePolicy',
  'animations',
  'textScale',
  'locale',
  'thermal',
  'lowPower',
  'deviceState',
  'declaredRate',
  'declaredRateChange',
  'tooFewVsyncs',
  'openAtTestEnd',
};

/// One place where a report breaks schema v1.
@immutable
final class SchemaProblem {
  /// Creates a problem at [path], such as `parts[2].metrics.janky`.
  const new(this.path, this.message);

  /// Where it is: keys joined by dots, list indices in brackets.
  final String path;

  /// What is wrong there.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is SchemaProblem && other.path == path && other.message == message;

  @override
  int get hashCode => Object.hash(path, message);

  @override
  String toString() => '$path: $message';
}

/// Checks a decoded report, the JSON of its `report` lines, against schema
/// v1 (`docs/report-schema.md`), and lists every problem found. None means
/// it matches.
///
/// A report of another schema version gets one problem and no other check.
List<SchemaProblem> checkReport(Object? report) {
  if (report case {'schema': final int version} when version != schemaVersion) {
    return [SchemaProblem('schema', 'expected $schemaVersion, got $version')];
  }
  final problems = <SchemaProblem>[];
  _report(report, '', problems);
  if (report case {
    'parts': List<Object?>(:final length),
    'issues': final List<Object?> issues,
  }) {
    for (final (i, issue) in issues.indexed) {
      if (issue case [final int part, ...] when part < 0 || part >= length) {
        problems.add(SchemaProblem('issues[$i][0]', 'names no part'));
      }
    }
  }
  return problems;
}

/// Checks decoded frame rows, read back from `frames` lines: each a list of
/// one integer per field in [frameFields].
List<SchemaProblem> checkFrames(List<Object?> frames) {
  final problems = <SchemaProblem>[];
  _listOf(_frame)(frames, 'frames', problems);
  return problems;
}

/// Checks [value] at [path], adding what is wrong to the list.
typedef _Shape = void Function(
  Object? value,
  String path,
  List<SchemaProblem> problems,
);

_Shape _type<T>(String expected, {bool orNull = false}) {
  return (value, path, problems) {
    if (value is T || (orNull && value == null)) return;
    problems.add(SchemaProblem(path, 'expected $expected, got $value'));
  };
}

_Shape _oneOf(Set<String> names) {
  return (value, path, problems) {
    if (names.contains(value)) return;
    problems.add(
      SchemaProblem(path, 'expected one of ${names.join(', ')}, got $value'),
    );
  };
}

_Shape _listOf(_Shape item) {
  return (value, path, problems) {
    if (value is! List<Object?>) {
      problems.add(SchemaProblem(path, 'expected a list, got $value'));
      return;
    }
    for (final (i, element) in value.indexed) {
      item(element, '$path[$i]', problems);
    }
  };
}

/// A list of [items] in order, the last [optional] of which may be left
/// out.
_Shape _tuple(List<_Shape> items, {int optional = 0}) {
  final fewest = items.length - optional;
  return (value, path, problems) {
    if (value is! List<Object?> ||
        value.length < fewest ||
        value.length > items.length) {
      final size = optional == 0
          ? '${items.length}'
          : '$fewest to ${items.length}';
      problems.add(SchemaProblem(path, 'expected a list of $size, got $value'));
      return;
    }
    for (final (i, element) in value.indexed) {
      items[i](element, '$path[$i]', problems);
    }
  };
}

/// A map holding every key of [fields], any of [optional], and nothing
/// else.
_Shape _object(
  Map<String, _Shape> fields, {
  Map<String, _Shape> optional = const {},
}) {
  return (value, path, problems) {
    if (value is! Map<String, Object?>) {
      problems.add(SchemaProblem(path, 'expected an object, got $value'));
      return;
    }
    String at(String key) => path.isEmpty ? key : '$path.$key';
    for (final key in fields.keys.where((key) => !value.containsKey(key))) {
      problems.add(SchemaProblem(at(key), 'missing'));
    }
    for (final MapEntry(:key, value: field) in value.entries) {
      final shape = fields[key] ?? optional[key];
      if (shape == null) {
        problems.add(SchemaProblem(at(key), 'not in schema v1'));
      } else {
        shape(field, at(key), problems);
      }
    }
  };
}

final _Shape _int = _type<int>('an integer');
final _Shape _intOrNull = _type<int>('an integer or null', orNull: true);
final _Shape _number = _type<num>('a number');
final _Shape _numberOrNull = _type<num>('a number or null', orNull: true);
final _Shape _string = _type<String>('a string');
final _Shape _stringOrNull = _type<String>('a string or null', orNull: true);
final _Shape _bool = _type<bool>('true or false');

final _Shape _frame = _tuple([for (final _ in frameFields) _int]);

final _Shape _reason = _tuple([
  _oneOf(guardNames),
  _string,
  _string,
], optional: 1);

final _Shape _identity = _object({
  'platform': _oneOf(const {'android', 'ios'}),
  'model': _stringOrNull,
  'osVersion': _stringOrNull,
  'buildMode': _oneOf(const {'debug', 'profile', 'release'}),
  'thermalAtStart': _stringOrNull,
  'flutterVersion': _stringOrNull,
  'engineRevision': _stringOrNull,
  'appCommit': _string,
  'textScale': _number,
  'locale': _string,
});

final _Shape _metrics = _object({
  'observedHz': _numberOrNull,
  'rateSlicesJudged': _int,
  'rateMismatches': _listOf(_tuple([_int, _int, _number])),
  'missedVsyncs': _int,
  'janky': _int,
  'severe': _int,
  'stalls': _int,
  for (final key in const [
    'hitchRatio',
    'hitchMs',
    'renderingMs',
    'missedVsyncMs',
    'jankyRate',
    'jankyRateUi',
    'jankyRateRaster',
    'jankyRateBoth',
    'uiP90B',
    'uiP99B',
    'worstUiB',
    'rasterP90B',
    'rasterP99B',
    'worstRasterB',
  ])
    key: _numberOrNull,
});

final _Shape _diagnostics = _object(
  {
    for (final key in const [
      'avgUiMs',
      'avgBuildMs',
      'avgRasterMs',
      'vsyncOverheadP90Ms',
      'vsyncOverheadP99Ms',
      'totalSpanP90Ms',
      'totalSpanP99Ms',
    ])
      key: _numberOrNull,
  },
  optional: {
    'rasterCachePeak': _object({
      'layers': _int,
      'layerBytes': _int,
      'pictures': _int,
      'pictureBytes': _int,
    }),
  },
);

/// The fields every part has.
final Map<String, _Shape> _partFields = {
  'kind': _oneOf(const {'test', 'span', 'episode'}),
  'name': _string,
  'startFrame': _int,
  'endFrame': _int,
  'startMicros': _int,
  'endMicros': _int,
  'declaredHz': _numberOrNull,
  'declaredHzAtEnd': _numberOrNull,
  'frames': _int,
  'diagnostics': _diagnostics,
};

/// Each kind of part's own fields: a span's verdict, an episode's test.
final Map<String, _Shape> _partsByKind = {
  'test': _object(_partFields, optional: {'metrics': _metrics}),
  'span': _object(
    {..._partFields, 'valid': _bool, 'reasons': _listOf(_reason)},
    optional: {
      'metrics': _metrics,
      'semantics': _tuple([_bool, _bool]),
    },
  ),
  'episode': _object(
    {..._partFields, 'test': _string},
    optional: {
      'metrics': _metrics,
      'page': _string,
      'declaredRateChanged': _bool,
    },
  ),
};

/// A part, checked against the fields of its kind. A part of no known
/// kind is checked against the fields every part has, which names its
/// kind as the problem.
void _part(Object? value, String path, List<SchemaProblem> problems) {
  final kind = value is Map<String, Object?> ? value['kind'] : null;
  (_partsByKind[kind] ?? _object(_partFields))(value, path, problems);
}

final _Shape _issue = _tuple([
  _int,
  _int,
  _number,
  _oneOf(const {'ui', 'raster', 'both'}),
  _number,
  _oneOf(const {'janky', 'severe', 'stall'}),
]);

final _Shape _report = _object({
  'schema': _int,
  'runId': _int,
  'identity': _identity,
  'valid': _bool,
  'reasons': _listOf(_reason),
  'frameCount': _int,
  'flushTimedOut': _bool,
  'flushMicros': _int,
  'callbackMicros': _int,
  'rateReads': _listOf(_tuple([_int, _intOrNull, _numberOrNull])),
  'parts': _listOf(_part),
  'issues': _listOf(_issue),
  'activity': _listOf(
    _tuple([
      _oneOf(const {'input', 'animation'}),
      _int,
      _int,
      _int,
      _int,
    ]),
  ),
  'pages': _listOf(_tuple([_int, _int, _stringOrNull, _bool])),
});
