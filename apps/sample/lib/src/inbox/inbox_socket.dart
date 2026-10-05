import 'dart:convert';
import 'dart:math';

/// One message in the inbox.
class Message {
  const new({
    required this.id,
    required this.sender,
    required this.subject,
    required this.body,
  });

  /// Reads a message from its JSON form.
  factory fromJson(Map<String, Object?> json) {
    return Message(
      id: json['id']! as int,
      sender: json['sender']! as String,
      subject: json['subject']! as String,
      body: json['body']! as String,
    );
  }

  /// Increases with every message the socket sends.
  final int id;
  final String sender;
  final String subject;
  final String body;
}

/// Decodes one batch of messages as the socket sends it.
List<Message> decodeBatch(String raw) {
  final list = jsonDecode(raw) as List<Object?>;
  return [
    for (final entry in list) Message.fromJson(entry! as Map<String, Object?>),
  ];
}

/// A fake socket that sends batches of messages as JSON, standing in for a
/// server push. The app decodes them for real.
///
/// Every call to [batches] starts the same sequence.
class InboxSocket {
  const new({
    this.seed = 11,
    this.batchSize = 20,
    this.period = const Duration(milliseconds: 500),
  });

  final int seed;

  /// Messages per batch.
  final int batchSize;

  /// How often a batch arrives.
  final Duration period;

  /// A JSON array of [batchSize] messages every [period].
  Stream<String> batches() {
    final random = Random(seed);
    var nextId = 0;
    return Stream.periodic(period, (_) {
      return jsonEncode([
        for (var i = 0; i < batchSize; i++) _message(nextId++, random),
      ]);
    });
  }
}

const _senders = ['Ana', 'Bo', 'Chen', 'Dara', 'Eli', 'Femi', 'Gus', 'Hana'];

const _topics = [
  'Your order has shipped',
  'A price you watched went down',
  'New items in your saved tags',
  'Someone replied to your review',
  'Your weekly summary',
  'A reminder about your list',
];

Map<String, Object> _message(int id, Random random) {
  final sender = _senders[random.nextInt(_senders.length)];
  final topic = _topics[random.nextInt(_topics.length)];
  return {
    'id': id,
    'sender': sender,
    'subject': '$topic (#${id + 1})',
    'body':
        'Hi, this is $sender. $topic. Open the app to see the details; '
        'nothing needs doing today.',
  };
}
