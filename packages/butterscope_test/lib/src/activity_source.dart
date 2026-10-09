import 'package:butterscope/butterscope.dart';
import 'package:flutter/gestures.dart' show GestureBinding, PointerEvent;
import 'package:flutter/scheduler.dart' show SchedulerBinding;

/// What a run is told about activity, to split its tests into episodes.
abstract interface class ActivityListener {
  /// A pointer event arrived.
  void input();

  /// Tickers started or stopped waiting for the next frame.
  void animating({required bool animating});

  /// The page on top changed to [page], its route name; [first] when it is
  /// the first page the app shows.
  void pageShown(String? page, {required bool first});
}

/// Where a run's activity comes from.
///
/// The run uses only this, so a host test can send activity by hand.
abstract interface class ActivitySource {
  /// Starts telling [listener] about activity.
  void start(ActivityListener listener);

  /// Stops telling it.
  void stop();
}

/// The [ActivitySource] of a running app, from public APIs of Flutter
/// 3.47.5, each passed on only when it changes:
///
/// - Input: every pointer event, through a global route of
///   `GestureBinding.pointerRouter` (`gestures/pointer_router.dart`). The
///   binding routes every event it dispatches there
///   (`GestureBinding.handleEvent`), the test's own taps and drags too.
/// - Animation: whether `SchedulerBinding.transientCallbackCount` is above
///   0, read in a persistent frame callback. Those run after the frame's
///   transient callbacks, so a count above 0 means a ticker waits for the
///   next frame. Under `benchmarkLive` the test binding asks the engine for
///   frames directly, which adds no transient callback.
/// - Pages: [ButterscopeRouteObserver], when the app has one.
final class EngineActivitySource implements ActivitySource {
  ActivityListener? _listener;
  var _framesWatched = false;
  var _animating = false;

  @override
  void start(ActivityListener listener) {
    _listener = listener;
    _animating = false;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    ButterscopeRouteObserver.listener = listener.pageShown;
    // A persistent frame callback cannot be removed, so it is added once
    // and does nothing while no run listens.
    if (!_framesWatched) {
      SchedulerBinding.instance.addPersistentFrameCallback((_) => _onFrame());
      _framesWatched = true;
    }
  }

  @override
  void stop() {
    if (_listener == null) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    ButterscopeRouteObserver.listener = null;
    _listener = null;
  }

  void _onPointer(PointerEvent event) => _listener?.input();

  void _onFrame() {
    final listener = _listener;
    if (listener == null) return;
    final animating = SchedulerBinding.instance.transientCallbackCount > 0;
    if (animating == _animating) return;
    _animating = animating;
    listener.animating(animating: animating);
  }
}
