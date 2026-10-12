import 'dart:math' as math;

/// The word every Butterscope line starts with.
///
/// Schema 0 printed `BSCOPE-REPORT`; the space after this tag keeps the two
/// apart, so a reader of one never takes the other's lines.
const String lineTag = 'BSCOPE';

/// The most characters of report JSON one `report` line carries.
///
/// Android's logcat cuts long lines (`docs/decisions/0002-m2-recorder-findings.md`),
/// and schema 0's 800-character lines arrived whole in every M5 and M6 run.
const int defaultChunkLength = 800;

/// The frames one `frames` line carries, except the last, which carries the
/// rest.
///
/// In M2 logcat dropped about 400 of 1,300 one-frame lines a run; with 20
/// frames a line it dropped none (`docs/measurements/m2.md`).
const int defaultFramesPerLine = 20;

/// The most lines of one kind a run may have. A line that claims more is
/// malformed, so no line can make a reader list more missing lines than
/// this.
///
/// 100,000 `report` lines hold 80 MB of JSON; 100,000 `frames` lines hold
/// 2,000,000 frames, over 4 hours at 120 Hz.
const int maxLineCount = 100000;

/// What a numbered line carries.
enum LineKind {
  /// A chunk of the report's JSON, without its frames.
  report,

  /// A JSON array of consecutive frames.
  frames,
}

/// Splits [text] into chunks of at most [length] UTF-16 code units, in
/// order.
///
/// A cut that would fall before a low surrogate (0xDC00 to 0xDFFF) moves
/// back one, so no chunk holds half a character that a log could mangle.
/// When [length] is 1 it moves forward instead, so that chunk holds the
/// whole pair, 2 code units. Throws a [RangeError] when [length] is below
/// 1.
List<String> chunk(String text, int length) {
  checkAtLeastOne(length, 'length');
  final chunks = <String>[];
  var start = 0;
  while (start < text.length) {
    var end = math.min(start + length, text.length);
    final cutsPair =
        end < text.length && (text.codeUnitAt(end) & 0xFC00) == 0xDC00;
    if (cutsPair) end += end - start > 1 ? -1 : 1;
    chunks.add(text.substring(start, end));
    start = end;
  }
  return chunks;
}

/// Throws a [RangeError] naming [name] when [value] is below 1.
void checkAtLeastOne(int value, String name) {
  if (value < 1) throw RangeError.range(value, 1, null, name);
}
