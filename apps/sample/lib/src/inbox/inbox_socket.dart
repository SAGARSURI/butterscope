import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

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

/// Reads UTF-8 bytes straight into JSON values.
final Converter<List<int>, Object?> _jsonFromUtf8 = utf8.decoder.fuse(
  json.decoder,
);

/// Decodes one batch of messages as the socket sends it.
List<Message> decodeBatch(TransferableTypedData raw) {
  final bytes = raw.materialize().asUint8List();
  final list = _jsonFromUtf8.convert(bytes)! as List<Object?>;
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
    this.headers = 0,
  });

  final int seed;

  /// Messages per batch.
  final int batchSize;

  /// How often a batch arrives.
  final Duration period;

  /// Header entries in each message, as a server might send for tracing.
  /// [Message.fromJson] skips them, but decoding must still parse them.
  final int headers;

  /// A JSON array of [batchSize] messages every [period], as UTF-8 bytes.
  ///
  /// The bytes can move to another isolate without a copy, as a real
  /// socket's would, so the clean build's UI isolate never holds a batch.
  Stream<TransferableTypedData> batches() {
    final random = Random(seed);
    final headerMap = {
      for (var i = 0; i < headers; i++)
        'x-header-$i': 'value-$i-${'0123456789abcdef' * 3}',
    };
    // Encoded once and spliced into every message, so making a batch
    // costs one copy of its bytes however many headers there are.
    final headerField = utf8.encode(
      headers == 0 ? '{' : '{"headers":${jsonEncode(headerMap)},',
    );
    var nextId = 0;
    return Stream.periodic(period, (_) {
      final parts = <TypedData>[_openList];
      for (var i = 0; i < batchSize; i++) {
        final message = jsonEncode(_message(nextId++, random));
        parts.addAll([
          if (i > 0) _comma,
          headerField,
          // The message without its opening brace, which headerField has.
          utf8.encode(message.substring(1)),
        ]);
      }
      parts.add(_closeList);
      return TransferableTypedData.fromList(parts);
    });
  }
}

final Uint8List _openList = utf8.encode('[');
final Uint8List _comma = utf8.encode(',');
final Uint8List _closeList = utf8.encode(']');

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
