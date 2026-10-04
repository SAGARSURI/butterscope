import 'package:butterscope/butterscope.dart';

import '../tool/m2/bscope_log.dart';

/// Writes numbered `BSCOPE` lines to [emit].
class BscopeWriter {
  new(this.emit);

  final void Function(String line) emit;
  var _seq = 0;

  /// Writes one line carrying [fields].
  void line(String kind, List<Object?> fields) {
    _seq++;
    emit([bscopeTag, _seq, kind, ...fields].join(' '));
  }

  /// Writes the line that closes the log, carrying the line count so a
  /// reader can tell whether any went missing.
  void done() => line('done', [_seq + 1]);

  /// Writes [window] as a header line, then its refresh-rate reads and
  /// samples, [perLine] to a line.
  ///
  /// Packing keeps the line count low: logcat drops lines when an app
  /// writes too many at once, and 20 samples stay under its line limit.
  void window(
    String name,
    RecordedWindow window,
    Map<String, Object> run, {
    int perLine = 20,
  }) {
    line('window', [
      name,
      for (final MapEntry(:key, :value) in run.entries) '$key=$value',
      'start=${window.startFrameNumber}',
      'end=${window.endFrameNumber}',
      'flushTimedOut=${window.flushTimedOut}',
      'flushMicros=${window.flushMicros}',
      'callbackMicros=${window.callbackMicros}',
      'rates=${window.refreshRateReads.length}',
      'samples=${window.samples.length}',
    ]);
    final rates = [
      for (final read in window.refreshRateReads)
        '${read.hertz}:${read.afterSamples}',
    ];
    final frames = [
      for (final sample in window.samples)
        [
          sample.frameNumber,
          sample.vsyncStartMicros,
          sample.buildMicros,
          sample.rasterMicros,
          sample.vsyncOverheadMicros,
        ].join(':'),
    ];
    for (final (kind, entries) in [('rates', rates), ('frames', frames)]) {
      for (var i = 0; i < entries.length; i += perLine) {
        final end = i + perLine < entries.length ? i + perLine : entries.length;
        line(kind, [name, ...entries.sublist(i, end)]);
      }
    }
  }
}
