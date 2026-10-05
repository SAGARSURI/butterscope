import 'dart:async';

import 'package:butterscope_sample/src/inbox/inbox_socket.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Messages as they arrive from the socket, newest first.
///
/// Each batch is decoded on a background isolate, so the UI thread only
/// inserts the result. While a message is open, new ones wait above the
/// list, so the one being read stays where it is; they join the list when
/// it closes.
class InboxScreen extends StatefulWidget {
  const new({required this.socket, super.key});

  final InboxSocket socket;

  /// The most messages kept on screen, and the most kept waiting.
  static const int limit = 200;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final List<Message> _messages = [];

  /// Messages that arrived while one was open, newest first.
  final List<Message> _waiting = [];

  /// The ids of the open messages.
  final Set<int> _open = {};

  late final StreamSubscription<List<Message>> _subscription;

  @override
  void initState() {
    super.initState();
    // compute sends the top-level function itself; a closure there would
    // capture this state, which cannot cross to another isolate. asyncMap
    // waits for each decode before the next, so batches land in the order
    // they arrived.
    _subscription = widget.socket
        .batches()
        .asyncMap((raw) => compute(decodeBatch, raw))
        .listen(_receive);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  void _receive(List<Message> batch) {
    setState(() {
      _prepend(_open.isEmpty ? _messages : _waiting, batch.reversed);
    });
  }

  void _setOpen(Message message, {required bool open}) {
    setState(() {
      if (open) {
        _open.add(message.id);
      } else {
        _open.remove(message.id);
      }
      if (_open.isEmpty) {
        _prepend(_messages, _waiting);
        _waiting.clear();
      }
    });
  }

  /// Puts [newestFirst] at the top of [list] and keeps the newest
  /// [InboxScreen.limit].
  static void _prepend(List<Message> list, Iterable<Message> newestFirst) {
    list.insertAll(0, newestFirst);
    if (list.length > InboxScreen.limit) {
      list.removeRange(InboxScreen.limit, list.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '${_messages.length} messages',
                key: const Key('inbox-count'),
              ),
              const Spacer(),
              if (_waiting.isNotEmpty)
                Text('${_waiting.length} new', key: const Key('inbox-waiting')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const Key('inbox-list'),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _MessageTile(
                message: message,
                onOpen: (open) => _setOpen(message, open: open),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const new({required this.message, required this.onOpen});

  final Message message;

  /// Called with true when the message opens, false when it closes.
  final ValueChanged<bool> onOpen;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: Key('message-${message.id}'),
      leading: CircleAvatar(child: Text(message.sender.substring(0, 1))),
      title: Text(message.subject),
      subtitle: Text(message.sender),
      onExpansionChanged: onOpen,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(message.body),
        ),
      ],
    );
  }
}
