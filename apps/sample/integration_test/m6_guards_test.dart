// M6's guard checks that need a test file of their own. Run it with:
//
//   VOID_SPANS='empty=tooFewVsyncs' \
//     TARGET=integration_test/m6_guards_test.dart \
//     tool/m6/run_tests.sh <id> guards
//
// By default the run is valid: one span with semantics on, as testWidgets
// leaves it, one with it off, and an empty span, which is void for lasting
// fewer than 11 vsyncs. With --dart-define=BUTTERSCOPE_FORCE=frame_policy
// (FORCE=frame_policy for the runner) a last test switches the binding to
// another frame policy, which voids the run.

import 'package:butterscope_test/butterscope_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachButterscope();
  const force = String.fromEnvironment('BUTTERSCOPE_FORCE');

  Future<void> scrollFeed(WidgetTester tester, int item) async {
    await tester.scrollUntilVisible(
      find.byKey(Key('item-card-$item')),
      400,
      scrollable: find.descendant(
        of: find.byKey(const Key('feed-list')),
        matching: find.byType(Scrollable),
      ),
    );
  }

  group('M6 guards', () {
    testWidgets('a span with semantics on, as testWidgets leaves it', (
      tester,
    ) async {
      await launchApp(tester);
      await span('feed scroll, semantics on', () => scrollFeed(tester, 39));
    });

    testWidgets('a span with semantics off', semanticsEnabled: false, (
      tester,
    ) async {
      await launchApp(tester);
      await span('feed scroll, semantics off', () => scrollFeed(tester, 39));
    });

    testWidgets('an empty span', semanticsEnabled: false, (tester) async {
      await launchApp(tester);
      await span('empty', () async {});
    });

    if (force == 'frame_policy') {
      testWidgets(
        'a test that leaves the frame policy',
        semanticsEnabled: false,
        (tester) async {
          await launchApp(tester);
          binding.framePolicy =
              LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;
        },
      );
    }
  });
}
