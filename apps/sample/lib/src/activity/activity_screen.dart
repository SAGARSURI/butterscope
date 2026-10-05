import 'dart:async';
import 'dart:math';

import 'package:butterscope_sample/src/activity/activity_source.dart';
import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/plant_costs.dart';
import 'package:butterscope_sample/src/plants/screen_plants.dart';
import 'package:butterscope_sample/src/widgets/item_art.dart';
import 'package:flutter/material.dart';

/// Live save counts for the first [rows] items in the catalogue, or all of
/// them when it holds fewer.
///
/// Each row listens to its own counter, so a bump rebuilds only its row.
/// The `rebuild_all` plant instead rebuilds and lays out every row on every
/// bump.
class ActivityScreen extends StatefulWidget {
  const new({required this.catalogue, required this.source, super.key});

  final Catalogue catalogue;
  final ActivitySource source;

  /// The most items with a counter.
  static const int rows = 40;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final List<ValueNotifier<int>> _counts = List.generate(
    min(ActivityScreen.rows, widget.catalogue.items.length),
    (_) => ValueNotifier(0),
  );

  late final bool _rebuildAll = PlantScope.of(context) == Plant.rebuildAll;

  /// Null when the catalogue is empty: with no rows, nothing listens.
  StreamSubscription<List<Bump>>? _subscription;

  @override
  void initState() {
    super.initState();
    if (_counts.isNotEmpty) {
      _subscription = widget.source.events(_counts.length).listen(_apply);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    for (final count in _counts) {
      count.dispose();
    }
    super.dispose();
  }

  void _apply(List<Bump> bumps) {
    for (final bump in bumps) {
      _counts[bump.index].value += bump.amount;
    }
    // The planted mistake: a setState at the top of the screen.
    if (_rebuildAll) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_rebuildAll) {
      // Every row built at once, in a column with no lazy building.
      final segments = rebuildAllSegments.value;
      return SingleChildScrollView(
        key: const Key('activity-list'),
        child: Column(
          children: [
            for (final (index, count) in _counts.indexed)
              _CounterTile(
                item: widget.catalogue.items[index],
                value: count.value,
                bar: SegmentedBar(
                  value: count.value % 100 / 100,
                  segments: segments,
                ),
              ),
          ],
        ),
      );
    }
    return ListView.builder(
      key: const Key('activity-list'),
      itemCount: _counts.length,
      itemBuilder: (context, index) => ValueListenableBuilder<int>(
        valueListenable: _counts[index],
        builder: (context, value, _) => _CounterTile(
          item: widget.catalogue.items[index],
          value: value,
          bar: LinearProgressIndicator(value: value % 100 / 100),
        ),
      ),
    );
  }
}

/// One item's row: its picture, title, a bar and the count.
class _CounterTile extends StatelessWidget {
  const new({required this.item, required this.value, required this.bar});

  final Item item;
  final int value;

  /// Shows how far the count is through its current hundred.
  final Widget bar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('counter-${item.id}'),
      leading: SizedBox.square(dimension: 40, child: ItemArt(item: item)),
      title: Text(item.title),
      subtitle: bar,
      trailing: Text('$value', key: Key('count-${item.id}')),
    );
  }
}
