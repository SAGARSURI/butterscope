import 'package:butterscope_sample/src/inbox/inbox_screen.dart';
import 'package:butterscope_sample/src/inbox/inbox_socket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

/// Lets the background decode of the batch that just arrived finish, then
/// draws the result: waits in real time until [count] messages show, for
/// at most 5 s.
Future<void> finishDecode(WidgetTester tester, int count) async {
  final shown = find.text('$count messages');
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
}
