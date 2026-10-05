import 'dart:async';

import 'package:butterscope_sample/src/inbox/inbox_socket.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Messages as they arrive from the socket, newest first.
///
/// Each batch is decoded on a background isolate, so the UI thread only
/// inserts the result.
class InboxScreen extends StatefulWidget {
  const new({required this.socket, super.key});

  final InboxSocket socket;

  /// The most messages kept on screen.
  static const int limit = 200;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final List<Message> _messages = [];
  late final StreamSubscription<String> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.socket.batches().listen(_receive);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  Future<void> _receive(String raw) async {
    // compute sends the top-level function itself; a closure here would
    // capture this state, which cannot cross to another isolate.
    final batch = await compute(decodeBatch, raw);
    if (!mounted) return;
    setState(() {
      _messages.insertAll(0, batch.reversed);
      if (_messages.length > InboxScreen.limit) {
        _messages.removeRange(InboxScreen.limit, _messages.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_messages.length} messages',
              key: const Key('inbox-count'),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const Key('inbox-list'),
            itemCount: _messages.length,
            itemBuilder: (context, index) =>
                _MessageTile(message: _messages[index]),
          ),
        ),
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const new({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: Key('message-${message.id}'),
      leading: CircleAvatar(child: Text(message.sender.substring(0, 1))),
      title: Text(message.subject),
      subtitle: Text(message.sender),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(message.body),
        ),
      ],
    );
  }
}
