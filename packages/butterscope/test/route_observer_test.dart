import 'dart:async';

import 'package:butterscope/butterscope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final shown = <(String?, bool)>[];

  setUp(() {
    shown.clear();
    ButterscopeRouteObserver.listener = (page, {required first}) {
      shown.add((page, first));
    };
  });

  tearDown(() => ButterscopeRouteObserver.listener = null);

  Future<NavigatorState> launch(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [ButterscopeRouteObserver()],
        home: const Text('home'),
      ),
    );
    return navigator.currentState!;
  }

  MaterialPageRoute<void> page(String name) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (context) => Text(name),
    );
  }

  testWidgets('reports the first page, then each page pushed and popped', (
    tester,
  ) async {
    final navigator = await launch(tester);
    navigator.push(page('detail'));
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(shown, [('/', true), ('detail', false), ('/', false)]);
  });

  testWidgets('reports the page that replaces another', (tester) async {
    final navigator = await launch(tester);
    navigator.pushReplacement(page('gallery'));
    await tester.pumpAndSettle();

    expect(shown, [('/', true), ('gallery', false)]);
  });

  testWidgets('reports the page left on top when one is removed', (
    tester,
  ) async {
    final navigator = await launch(tester);
    final detail = page('detail');
    navigator.push(detail);
    await tester.pumpAndSettle();
    navigator.removeRoute(detail);
    await tester.pumpAndSettle();

    expect(shown, [('/', true), ('detail', false), ('/', false)]);
  });

  testWidgets('leaves out a page replaced under the one on top', (
    tester,
  ) async {
    final navigator = await launch(tester);
    final detail = page('detail');
    navigator.push(detail);
    await tester.pumpAndSettle();
    navigator.replaceRouteBelow(anchorRoute: detail, newRoute: page('feed'));
    await tester.pumpAndSettle();

    expect(shown, [('/', true), ('detail', false)]);
  });

  testWidgets('reports a page change after the app rebuilds its observer', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    // Each pump builds a new observer, as an app that creates it in
    // `build` does whenever its root rebuilds.
    Widget app() {
      return MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [ButterscopeRouteObserver()],
        home: const Text('home'),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpWidget(app());
    navigator.currentState!.push(page('detail'));
    await tester.pumpAndSettle();

    expect(shown, [('/', true), ('detail', false)]);
  });

  testWidgets('starts nothing when a dialog open across a rebuild closes', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    Widget app() {
      return MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [ButterscopeRouteObserver()],
        home: const Text('home'),
      );
    }

    await tester.pumpWidget(app());
    final context = tester.element(find.text('home'));
    unawaited(
      showDialog<void>(context: context, builder: (context) => const Text('?')),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    navigator.currentState!.push(page('detail'));
    await tester.pumpAndSettle();

    // Home shows again when the dialog closes: no change. The page pushed
    // after it is one.
    expect(shown, [('/', true), ('/', true), ('detail', false)]);
  });

  testWidgets('reports a page pushed over a dialog after a rebuild', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    Widget app() {
      return MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [ButterscopeRouteObserver()],
        home: const Text('home'),
      );
    }

    await tester.pumpWidget(app());
    final context = tester.element(find.text('home'));
    unawaited(
      showDialog<void>(context: context, builder: (context) => const Text('?')),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    navigator.currentState!.push(page('detail'));
    await tester.pumpAndSettle();

    expect(shown, [('/', true), ('detail', false)]);
  });

  testWidgets('reports the first page of each navigator it is added to', (
    tester,
  ) async {
    // One observer, kept across two launches of the app, as a top-level
    // final in the app would be across tests.
    final observer = ButterscopeRouteObserver();
    Widget app(Key key) {
      return MaterialApp(
        key: key,
        navigatorObservers: [observer],
        home: const Text('home'),
      );
    }

    await tester.pumpWidget(app(const ValueKey(1)));
    await tester.pumpWidget(app(const ValueKey(2)));

    expect(shown, [('/', true), ('/', true)]);
  });

  testWidgets('leaves dialogs out, since they are not pages', (tester) async {
    await launch(tester);
    final context = tester.element(find.text('home'));
    unawaited(
      showDialog<void>(context: context, builder: (context) => const Text('?')),
    );
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();

    expect(shown, [('/', true)]);
  });

  testWidgets('does nothing while no run records', (tester) async {
    ButterscopeRouteObserver.listener = null;
    final navigator = await launch(tester);
    navigator.push(page('detail'));
    await tester.pumpAndSettle();

    expect(shown, isEmpty);
  });
}
