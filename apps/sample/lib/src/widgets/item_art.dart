import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:flutter/material.dart';

/// An item's picture: a gradient in the item's own colour with its
/// initial on top. Decorative: screen readers skip it, since the title is
/// always shown beside it.
class ItemArt extends StatelessWidget {
  const new({required this.item, super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    // 37 is coprime with 360, so neighbouring ids get distant hues.
    final hue = (item.id * 37 % 360).toDouble();
    final light = HSVColor.fromAHSV(1, hue, 0.35, 0.95).toColor();
    final dark = HSVColor.fromAHSV(1, (hue + 40) % 360, 0.6, 0.7).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, dark],
        ),
      ),
      child: ExcludeSemantics(
        child: Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                item.title.substring(0, 1),
                style: const TextStyle(color: Colors.white70, fontSize: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
