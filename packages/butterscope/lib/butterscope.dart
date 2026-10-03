/// Records every frame Flutter renders during a test run and reports jank
/// per flow.
///
/// M1 provides the metrics engine: frame classes, window metrics, nearest-rank
/// percentiles and the observed refresh rate. See `docs/DESIGN.md` at the
/// repository root.
library;

export 'package:butterscope/src/classified_frame.dart';
export 'package:butterscope/src/frame_budget.dart';
export 'package:butterscope/src/frame_sample.dart';
export 'package:butterscope/src/percentile.dart';
export 'package:butterscope/src/refresh_rate.dart';
export 'package:butterscope/src/window_metrics.dart';
