import 'dart:convert';

/// The CRC-32 of [text]'s UTF-8 bytes, as 8 lowercase hex digits.
///
/// The IEEE 802.3 polynomial (reflected, 0xEDB88320), as zlib and PNG use,
/// so `crc32('123456789')` is `cbf43926`, the standard check value. Each
/// numbered line carries the CRC of its header and payload (`LineWriter`),
/// so a reader can tell a line that a log cut or mangled from one that
/// arrived whole.
String crc32(String text) {
  var crc = 0xFFFFFFFF;
  for (final byte in utf8.encode(text)) {
    crc = _table[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
  }
  return ((crc ^ 0xFFFFFFFF) & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}

/// The CRC of every byte value, so each byte costs one lookup.
final List<int> _table = List.generate(256, (value) {
  var crc = value;
  for (var bit = 0; bit < 8; bit++) {
    crc = crc.isOdd ? 0xEDB88320 ^ (crc >>> 1) : crc >>> 1;
  }
  return crc;
});
