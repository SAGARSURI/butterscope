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

  /// Writes [window] as a header line, one line per refresh-rate read and
  /// one per sample.
  void window(String name, RecordedWindow window, Map<String, Object> run) {
    line('window', [
      name,
      for (final MapEntry(:key, :value) in run.entries) '$key=$value',
      'start=${window.startFrameNumber}',
      'end=${window.endFrameNumber}',
      'flushTimedOut=${window.flushTimedOut}',
      'flushMicros=${window.flushMicros}',
      'callbackMicros=${window.callbackMicros}',
      'samples=${window.samples.length}',
    ]);
    for (final read in window.refreshRateReads) {
      line('rate', [name, read.hertz, read.afterSamples]);
    }
    for (final sample in window.samples) {
      line('frame', [
        name,
        sample.frameNumber,
        sample.vsyncStartMicros,
        sample.buildMicros,
        sample.rasterMicros,
        sample.vsyncOverheadMicros,
      ]);
    }
  }
}
