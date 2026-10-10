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
/// navigator's first page starts no episode. That is read from the
/// navigator, so an app may create the observer in `build`: one that
/// replaces another on a rebuild hears the next page as a change.
class ButterscopeRouteObserver extends NavigatorObserver {
  /// Gets each change of page while a run records. `butterscope_test` sets
  /// it when it starts recording and clears it when it stops.
  static PageListener? listener;

  Route<dynamic>? _page;

  // Flutter 3.47.6 calls this once the navigator's history settles, with
  // the route now on top (`widgets/navigator.dart`, `_flushHistoryUpdates`).
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (topRoute is! PageRoute || identical(topRoute, _page)) return;
    _page = topRoute;
    listener?.call(topRoute.settings.name, first: previousTopRoute == null);
  }
}
