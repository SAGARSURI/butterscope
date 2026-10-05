import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/detail/detail_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/plant_costs.dart';
import 'package:butterscope_sample/src/plants/raster_plants.dart';
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
    final card = Card(
      key: Key('item-card-${item.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(item),
        // The text sets the height, so large text grows the card; the
        // picture keeps its size at the top.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(dimension: 112, child: ItemArt(item: item)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _CardText(item: item, theme: theme),
              ),
            ),
          ],
        ),
      ),
    );
    if (PlantScope.of(context) != Plant.rasterClip) return card;
    return SlowRasterPlant(
      depth: rasterClipLayers.value,
      fade: 0.9,
      child: card,
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
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 12),
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
