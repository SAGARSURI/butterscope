import 'package:flutter/widgets.dart';

/// Receives each change of the page on top: its route name, and whether it
/// is the first page the navigator shows.
typedef PageListener = void Function(String? page, {required bool first});

/// Tags episodes with the page on top of the app's navigator.
///
/// Add it to the app's `MaterialApp`, so it is there whatever runs the app:
///
/// ```dart
/// MaterialApp(navigatorObservers: [ButterscopeRouteObserver()], ...)
/// ```
///
/// While Butterscope records a test run, a change of page also starts a new
/// episode. Outside a run it does nothing, so it can stay in a release
/// build. It follows the page route on top, however it got there: pushed,
/// popped, replaced or removed. A dialog or a menu is not a page, so it
/// changes nothing, and a page is named by its route's
/// [RouteSettings.name].
///
/// It belongs on the app's root navigator only: a run hears one page at a
/// time, so the pages of nested navigators would interleave. The
/// navigator's first page starts no episode. What it knows is kept for the
/// navigator, so an app may create the observer in `build`: one that
/// replaces another on a rebuild carries on from the page on top.
class ButterscopeRouteObserver extends NavigatorObserver {
  /// Gets each change of page while a run records. `butterscope_test` sets
  /// it when it starts recording and clears it when it stops.
  static PageListener? listener;

  /// The page each navigator last showed, kept for the navigator rather
  /// than the observer, so an observer that replaces another on a rebuild
  /// still knows the page on top.
  static final _pages = Expando<Route<dynamic>>();

  // Flutter 3.47.6 calls this once the navigator's history settles, with
  // the route now on top (`widgets/navigator.dart`, `_flushHistoryUpdates`).
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    final navigator = this.navigator;
    if (topRoute is! PageRoute || navigator == null) return;
    if (identical(topRoute, _pages[navigator])) return;
    _pages[navigator] = topRoute;
    // Nothing was on top before the navigator's first page.
    listener?.call(topRoute.settings.name, first: previousTopRoute == null);
  }
}
