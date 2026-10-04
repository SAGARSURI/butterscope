/// Records every frame Flutter renders during a test run and reports jank
/// per flow.
///
/// M1 provides the metrics engine: frame classes, window metrics,
/// nearest-rank percentiles, missed vsyncs and the observed refresh rate.
/// M2 adds the frame recorder, which stores the frames of a window on a
/// phone for the engine to measure.
/// See `docs/DESIGN.md` at the repository root.
library;

export 'package:butterscope/src/classified_frame.dart';
export 'package:butterscope/src/frame_budget.dart';
export 'package:butterscope/src/frame_recorder.dart';
export 'package:butterscope/src/frame_sample.dart';
export 'package:butterscope/src/frame_source.dart';
export 'package:butterscope/src/missed_vsyncs.dart';
export 'package:butterscope/src/percentile.dart';
export 'package:butterscope/src/recorded_window.dart';
export 'package:butterscope/src/refresh_rate.dart';
export 'package:butterscope/src/window_metrics.dart';
