import 'dart:ui' show ImageFilter;

import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/plant_costs.dart';
import 'package:butterscope_sample/src/plants/raster_plants.dart';
import 'package:butterscope_sample/src/widgets/item_art.dart';
import 'package:butterscope_sample/src/widgets/item_tile.dart';
import 'package:flutter/material.dart';

/// Pushes the detail page for [item].
Future<void> openDetail(BuildContext context, Catalogue catalogue, Item item) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DetailScreen(catalogue: catalogue, item: item),
    ),
  );
}

/// One item: a large picture under a frosted title panel, its details,
/// and related items below.
class DetailScreen extends StatelessWidget {
  const new({required this.catalogue, required this.item, super.key});

  final Catalogue catalogue;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final related = catalogue.related(item);
    return Scaffold(
      body: CustomScrollView(
        key: const Key('detail-scroll'),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            flexibleSpace: FlexibleSpaceBar(background: _Header(item: item)),
          ),
          SliverToBoxAdapter(child: _Facts(item: item)),
          SliverList.builder(
            itemCount: related.length,
            itemBuilder: (context, index) => ItemTile(
              item: related[index],
              onTap: () => openDetail(context, catalogue, related[index]),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(key: Key('detail-end'), height: 32),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ItemArt(item: item),
        if (PlantScope.of(context) == Plant.gpuBlur)
          ClipRect(
            child: BackdropBlurPlant(layers: gpuBlurLayers.value, sigma: 40),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ColoredBox(
                color: Colors.white24,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    item.title,
                    key: const Key('detail-title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Facts extends StatelessWidget {
  const new({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.summary, style: textTheme.bodyLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [for (final tag in item.tags) Chip(label: Text(tag))],
          ),
          const SizedBox(height: 16),
          Text('Rated ${item.rating.toStringAsFixed(1)} of 5'),
          Text('Saved by ${item.saves} people'),
          const SizedBox(height: 24),
          Text('Related', style: textTheme.titleMedium),
        ],
      ),
    );
  }
}
