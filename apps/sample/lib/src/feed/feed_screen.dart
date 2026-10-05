import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/detail/detail_screen.dart';
import 'package:butterscope_sample/src/widgets/item_art.dart';
import 'package:flutter/material.dart';

/// Every item in the catalogue as a scrolling list of cards.
class FeedScreen extends StatelessWidget {
  const new({required this.catalogue, super.key});

  final Catalogue catalogue;

  @override
  Widget build(BuildContext context) {
    final items = catalogue.items;
    return ListView.builder(
      key: const Key('feed-list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => ItemCard(
        item: items[index],
        onOpen: (item) => openDetail(context, catalogue, item),
      ),
    );
  }
}

/// A card showing an item's picture, title, tags and rating.
class ItemCard extends StatelessWidget {
  const new({required this.item, required this.onOpen, super.key});

  final Item item;

  /// Called with [item] when the card is tapped.
  final ValueChanged<Item> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('item-card-${item.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(item),
        child: SizedBox(
          height: 112,
          child: Row(
            children: [
              SizedBox(width: 112, child: ItemArt(item: item)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _CardText(item: item, theme: theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardText extends StatelessWidget {
  const new({required this.item, required this.theme});

  final Item item;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(item.tags.join(' · '), style: theme.textTheme.bodySmall),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.star, size: 16),
            const SizedBox(width: 4),
            Text(item.rating.toStringAsFixed(1)),
            const Spacer(),
            Text('${item.saves} saves', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
