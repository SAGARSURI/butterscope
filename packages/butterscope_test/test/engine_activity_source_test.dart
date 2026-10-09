// The engine's activity signals, in an ordinary widget test: the same
// pointer router, scheduler and navigator observer a phone run uses.

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/activity_source.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class HeardActivity implements ActivityListener {
  final heard = <String>[];

  @override
  void input() {
    // A tap is a down and an up; one entry per run of them is enough here.
    if (heard.isEmpty || heard.last != 'input') heard.add('input');
  }

  @override
  void animating({required bool animating}) {
    heard.add(animating ? 'animating' : 'still');
  }

  @override
  void pageShown(String? page, {required bool first}) {
    heard.add('page $page${first ? ' first' : ''}');
  }
}

void main() {
  final source = EngineActivitySource();
  late HeardActivity listener;

  setUp(() => source.start(listener = HeardActivity()));
  tearDown(source.stop);

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [ButterscopeRouteObserver()],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'detail'),
                builder: (context) => const Text('detail'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('hears a tap, the animation it starts and the page', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The button opens the page on the pointer up, before the global
    // route hears the up. The ink splash and the page transition then run
    // on tickers, seen at the next frame, until the screen settles.
    expect(listener.heard, [
      'page / first',
      'input',
      'page detail',
      'input',
      'animating',
      'still',
    ]);
  });

  testWidgets('leaves a mouse hovering out of input', (tester) async {
    await launch(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('open')));
    await mouse.removePointer();
    await tester.pumpAndSettle();

    expect(listener.heard, ['page / first']);
  });

  testWidgets('hears nothing once stopped', (tester) async {
    await launch(tester);
    source.stop();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(listener.heard, ['page / first']);
    // tearDown stops it again, which does nothing.
  });
}
