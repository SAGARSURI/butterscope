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
