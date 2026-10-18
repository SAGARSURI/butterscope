import 'dart:math' as math;

/// The word every Butterscope line starts with.
///
/// Schema 0 printed `BSCOPE-REPORT`; the space after this tag keeps the two
/// apart, so a reader of one never takes the other's lines.
const String lineTag = 'BSCOPE';

/// The most characters of report JSON one `report` line carries.
///
/// Device logs can cut long lines (`docs/DESIGN.md` section 8). Schema 0's
/// 800-character lines arrived whole in every counted M5 run
/// (`docs/measurements/m5.md`), and v1's in every M7 run on both phones,
/// in profile and release (`docs/measurements/m7.md`).
const int defaultChunkLength = 800;

/// The frames one `frames` line carries, except the last, which carries the
/// rest.
///
/// In M2 logcat dropped about 400 of 1,300 one-frame lines a run, and
/// packing 20 frames a line fixed it (`docs/measurements/m2.md`).
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
/// A cut moves back while it would fall before a low surrogate (0xDC00 to
/// 0xDFFF) or after whitespace. So no chunk holds half a character that a
/// log could mangle, and no chunk but the last ends in whitespace, which
/// the iPhone's system log strips from the end of a line (M7's first
/// iPhone release run lost one space that way). When moving back would
/// leave the chunk empty, the cut moves forward instead, and that chunk is
/// longer than [length]: a pair when [length] is 1, or a run of whitespace
/// longer than [length] with the character after it. Throws a [RangeError]
/// when [length] is below 1.
List<String> chunk(String text, int length) {
  checkAtLeastOne(length, 'length');
  final chunks = <String>[];
  var start = 0;
  while (start < text.length) {
    final end = _cut(text, start, math.min(start + length, text.length));
    chunks.add(text.substring(start, end));
    start = end;
  }
  return chunks;
}

/// Where the chunk of [text] from [start] ends, given that it may run to
/// [end]: [end] itself when that is a good cut, else the nearest good cut
/// before it, else the nearest after it.
int _cut(String text, int start, int end) {
  var cut = end;
  while (cut > start && _isBadCut(text, cut)) {
    cut--;
  }
  if (cut > start) return cut;
  cut = end;
  while (_isBadCut(text, cut)) {
    cut++;
  }
  return cut;
}

/// Whether a cut of [text] at [cut] would fall before a low surrogate or
/// after whitespace. The end of [text] is always a good cut.
bool _isBadCut(String text, int cut) {
  if (cut >= text.length) return false;
  final isLowSurrogate = (text.codeUnitAt(cut) & 0xFC00) == 0xDC00;
  return isLowSurrogate || text[cut - 1].trim().isEmpty;
}

/// Throws a [RangeError] naming [name] when [value] is below 1.
void checkAtLeastOne(int value, String name) {
  if (value < 1) throw RangeError.range(value, 1, null, name);
}
