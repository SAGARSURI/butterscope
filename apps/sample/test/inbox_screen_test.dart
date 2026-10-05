import 'package:butterscope_sample/src/inbox/inbox_screen.dart';
import 'package:butterscope_sample/src/inbox/inbox_socket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

/// Lets the background decode of the batch that just arrived finish, then
/// draws the result: waits in real time until [count] messages show, for
/// at most 5 s.
Future<void> finishDecode(WidgetTester tester, int count) {
  return pumpUntil(tester, find.text('$count messages'));
}

/// Pumps in real time until [shown] finds something, for at most 5 s.
Future<void> pumpUntil(WidgetTester tester, Finder shown) async {
  for (var i = 0; i < 100 && shown.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('shows each batch as it arrives, newest first', (tester) async {
    const socket = InboxSocket(batchSize: 2);
    await tester.pumpWidget(inApp(const InboxScreen(socket: socket)));
    expect(find.text('0 messages'), findsOneWidget);

    await tester.pump(socket.period);
    await finishDecode(tester, 2);

    // The first batch holds ids 0 and 1; the newest, 1, comes first.
    expect(find.text('2 messages'), findsOneWidget);
    final top = tester.getTopLeft(find.byKey(const Key('message-1')));
    final below = tester.getTopLeft(find.byKey(const Key('message-0')));
    expect(top.dy, lessThan(below.dy));
  });

  testWidgets('tapping a message shows its text', (tester) async {
    const socket = InboxSocket(batchSize: 1);
    await tester.pumpWidget(inApp(const InboxScreen(socket: socket)));
    await tester.pump(socket.period);
    await finishDecode(tester, 1);
    final body = find.textContaining('Open the app to see the details');
    expect(body, findsNothing);

    await tester.tap(find.byKey(const Key('message-0')));
    await tester.pumpAndSettle();

    expect(body, findsOneWidget);
  });

  testWidgets('keeps only the newest 200', (tester) async {
    const socket = InboxSocket(batchSize: 150);
    await tester.pumpWidget(inApp(const InboxScreen(socket: socket)));

    await tester.pump(socket.period);
    await finishDecode(tester, 150);
    await tester.pump(socket.period);
    await finishDecode(tester, 200);

    // Two batches send ids 0 to 299; the newest 200 are 299 down to 100.
    expect(find.text('200 messages'), findsOneWidget);
    expect(find.byKey(const Key('message-299')), findsOneWidget);
  });

  testWidgets('an open message stays put while new ones wait above', (
    tester,
  ) async {
    const socket = InboxSocket(batchSize: 1);
    await tester.pumpWidget(inApp(const InboxScreen(socket: socket)));
    await tester.pump(socket.period);
    await finishDecode(tester, 1);
    final first = find.byKey(const Key('message-0'));
    await tester.tap(first);
    await tester.pumpAndSettle();
    final place = tester.getTopLeft(first);

    await tester.pump(socket.period);
    await pumpUntil(tester, find.text('1 new'));

    expect(find.text('1 messages'), findsOneWidget);
    expect(tester.getTopLeft(first), place);
    expect(
      find.textContaining('Open the app to see the details'),
      findsOneWidget,
    );
  });

  testWidgets('waiting messages join the top when the open one closes', (
    tester,
  ) async {
    const socket = InboxSocket(batchSize: 1);
    await tester.pumpWidget(inApp(const InboxScreen(socket: socket)));
    await tester.pump(socket.period);
    await finishDecode(tester, 1);
    final first = find.byKey(const Key('message-0'));
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.pump(socket.period);
    await pumpUntil(tester, find.text('1 new'));

    // Tapping the open message's header closes it.
    await tester.tap(find.textContaining('(#1)'));
    await tester.pumpAndSettle();

    expect(find.text('2 messages'), findsOneWidget);
    expect(find.byKey(const Key('inbox-waiting')), findsNothing);
    final newest = tester.getTopLeft(find.byKey(const Key('message-1')));
    expect(newest.dy, lessThan(tester.getTopLeft(first).dy));
  });
}
