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
/// episode. Outside a run it does nothing. It follows page routes only, so
/// a dialog or a menu does not count as a page, and a page is named by its
/// route's [RouteSettings.name].
class ButterscopeRouteObserver extends NavigatorObserver {
  /// Gets each change of page while a run records. `butterscope_test` sets
  /// it when it starts recording and clears it when it stops.
  static PageListener? listener;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _show(route, first: previousRoute == null);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute is PageRoute) {
      _show(previousRoute, first: false);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute) _show(newRoute, first: oldRoute == null);
  }

  void _show(Route<dynamic> route, {required bool first}) {
    listener?.call(route.settings.name, first: first);
  }
}
