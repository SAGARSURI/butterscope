import 'package:butterscope_report/butterscope_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the standard CRC-32 check value', () {
    // The check value every CRC-32/ISO-HDLC implementation publishes for
    // the nine ASCII digits.
    expect(crc32('123456789'), 'cbf43926');
  });

  test('is 8 zero digits for no bytes', () {
    // The register starts at 0xFFFFFFFF and is inverted at the end, so no
    // bytes give 0xFFFFFFFF ^ 0xFFFFFFFF = 0.
    expect(crc32(''), '00000000');
  });

  test('pads to 8 digits', () {
    // Python's zlib.crc32(b'[1,2]') is 0x088b50bf: a leading zero.
    expect(crc32('[1,2]'), '088b50bf');
  });

  test('covers the UTF-8 bytes, not the UTF-16 code units', () {
    // 'é' is the bytes C3 A9; zlib.crc32 of those is 0x0e048d3e.
    expect(crc32('é'), '0e048d3e');
  });

  test('changes when one character changes', () {
    expect(crc32('{"a":1}'), isNot(crc32('{"a":2}')));
  });
}
