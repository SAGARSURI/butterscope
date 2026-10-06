import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/widgets/item_art.dart';
import 'package:flutter/material.dart';

/// A one-line list entry for an item, with a small picture.
class ItemTile extends StatelessWidget {
  const new({required this.item, required this.onTap, super.key});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // No key from the item: when a list shows other items in the same
    // places, as search results do on each keystroke, the tiles are updated
    // in place instead of built again from scratch.
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(dimension: 48, child: ItemArt(item: item)),
      ),
      title: Text(item.title),
      subtitle: Text(item.tags.join(' · ')),
      trailing: Text(item.rating.toStringAsFixed(1)),
      onTap: onTap,
    );
  }
}
