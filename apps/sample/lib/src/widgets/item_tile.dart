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
    return ListTile(
      key: Key('item-tile-${item.id}'),
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
