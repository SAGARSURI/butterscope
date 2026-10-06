import 'dart:math';
import 'dart:typed_data';

import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:flutter/material.dart';

/// The search the `ui_busy` plant runs: the same results as
/// [Catalogue.search], best match first.
///
/// The mistake is scoring every item in the catalogue on the UI thread, on
/// every keystroke. An item's score is the smallest edit distance from the
/// query to any of the first [words] words of its title, tags and summary;
/// items with the same score stay in id order.
List<Item> fuzzySearch(
  Catalogue catalogue,
  String query, {
  required int words,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final scores = <int>[];
  for (final item in catalogue.items) {
    final distances = '${item.title} ${item.tags.join(' ')} ${item.summary}'
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((word) => word.isNotEmpty)
        .take(words)
        .map((word) => _editDistance(needle, word))
        .toList();
    // An item with no words is as far as an empty word: the query's length.
    scores.add(distances.isEmpty ? needle.length : distances.reduce(min));
  }
  // An item's id is its position in the catalogue.
  return catalogue.search(needle)..sort((a, b) {
    final byScore = scores[a.id].compareTo(scores[b.id]);
    return byScore != 0 ? byScore : a.id.compareTo(b.id);
  });
}

/// The fewest single-letter insertions, deletions and substitutions that
/// turn [a] into [b] (Levenshtein distance), kept two rows at a time.
int _editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (j) => j);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final substitution = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = min(
        min(current[j - 1], previous[j]) + 1,
        previous[j - 1] + substitution,
      );
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

/// A progress bar drawn as [segments] separate boxes, for `rebuild_all`:
/// every box is built and laid out again whenever the bar is.
class SegmentedBar extends StatelessWidget {
  const new({required this.value, required this.segments, super.key});

  /// From 0 to 1: the share of segments filled.
  final double value;

  final int segments;

  @override
  Widget build(BuildContext context) {
    final filled = (value * segments).round();
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 4,
      child: Row(
        children: [
          for (var i = 0; i < segments; i++)
            Expanded(
              child: ColoredBox(
                color: i < filled
                    ? colors.primary
                    : colors.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }
}

/// The average colour of [rgba], pixels of four bytes each (red, green,
/// blue, alpha), ignoring alpha.
Color averageColour(ByteData rgba) {
  final bytes = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
  final pixels = bytes.length ~/ 4;
  var red = 0;
  var green = 0;
  var blue = 0;
  for (var i = 0; i < pixels * 4; i += 4) {
    red += bytes[i];
    green += bytes[i + 1];
    blue += bytes[i + 2];
  }
  return Color.fromARGB(255, red ~/ pixels, green ~/ pixels, blue ~/ pixels);
}

/// A gallery cell for `photo_tint`: [child] on a frame in the colour of
/// [photo], once that colour is worked out.
///
/// The mistake is working the colour out from every pixel of a [width]
/// pixel copy of the photo, on the UI thread, each time the cell is built
/// into the grid, instead of once per photo from a small copy. Flutter
/// decodes the copy on a background thread and caches it; reading its
/// pixels back and averaging them is the cost.
class TintedPhoto extends StatefulWidget {
  const new({
    required this.photo,
    required this.width,
    required this.child,
    super.key,
  });

  final ImageProvider photo;

  /// The width in pixels of the copy whose pixels are averaged.
  final int width;

  final Widget child;

  @override
  State<TintedPhoto> createState() => _TintedPhotoState();
}

class _TintedPhotoState extends State<TintedPhoto> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(_read);
  Color? _tint;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= _resolve();
  }

  @override
  void didUpdateWidget(TintedPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo == oldWidget.photo && widget.width == oldWidget.width) {
      return;
    }
    _stream?.removeListener(_listener);
    _stream = _resolve();
  }

  ImageStream _resolve() {
    final provider = ResizeImage(widget.photo, width: widget.width);
    return provider.resolve(createLocalImageConfiguration(context))
      ..addListener(_listener);
  }

  Future<void> _read(ImageInfo info, bool synchronousCall) async {
    final rgba = await info.image.toByteData();
    // The stream hands each listener its own handle to the image.
    info.dispose();
    if (rgba == null || !mounted) return;
    setState(() => _tint = averageColour(rgba));
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('photo-tint'),
      color: _tint ?? Colors.transparent,
      child: Padding(padding: const EdgeInsets.all(4), child: widget.child),
    );
  }
}
