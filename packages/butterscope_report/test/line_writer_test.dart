import 'package:butterscope_report/butterscope_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prints the start line with the run id', () {
    expect(LineWriter(42).start(), 'BSCOPE 42 start');
  });

  test('numbers report chunks and stamps each with its CRC', () {
    // jsonEncode({'a': 12345}) is {"a":12345}, 11 characters: chunks of 8
    // are {"a":123 and 45}.
    final lines = LineWriter(7, chunkLength: 8).report({'a': 12345});

    expect(lines, [
      'BSCOPE 7 report 1/2 ${crc32('{"a":123')} {"a":123',
      'BSCOPE 7 report 2/2 ${crc32('45}')} 45}',
    ]);
  });

  test('packs frames into lines of framesPerLine, the last with the rest', () {
    // 5 frames at 2 a line: [0,1], [2,3], [4].
    final frames = [
      for (var i = 0; i < 5; i++) [i],
    ];
    final lines = LineWriter(7, framesPerLine: 2).frames(frames);

    expect(lines, [
      'BSCOPE 7 frames 1/3 ${crc32('[[0],[1]]')} [[0],[1]]',
      'BSCOPE 7 frames 2/3 ${crc32('[[2],[3]]')} [[2],[3]]',
      'BSCOPE 7 frames 3/3 ${crc32('[[4]]')} [[4]]',
    ]);
  });

  test('prints no frame lines for no frames', () {
    expect(LineWriter(7).frames(const []), isEmpty);
  });

  test('defaults to 800-character chunks and 20 frames a line', () {
    final writer = LineWriter(7);

    expect(writer.chunkLength, 800);
    expect(writer.framesPerLine, 20);
  });

  test('refuses a chunk length or frames per line below 1', () {
    expect(() => LineWriter(7, chunkLength: 0), throwsRangeError);
    expect(() => LineWriter(7, framesPerLine: 0), throwsRangeError);
  });

  group('chunk', () {
    test('cuts at the length, keeping every character in order', () {
      expect(chunk('abcdefg', 3), ['abc', 'def', 'g']);
    });

    test('never splits a surrogate pair', () {
      // 'a😀b' is a, high surrogate, low surrogate, b. A cut at 2 would
      // fall before the low surrogate, so the first chunk ends after a.
      expect(chunk('a😀b', 2), ['a', '😀', 'b']);
    });

    test('gives no chunks for empty text', () {
      expect(chunk('', 3), isEmpty);
    });
  });
}
