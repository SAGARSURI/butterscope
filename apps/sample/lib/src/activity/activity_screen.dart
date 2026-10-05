import 'dart:async';

import 'package:butterscope_sample/src/activity/activity_source.dart';
import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/widgets/item_art.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Live save counts for the first items in the catalogue.
///
/// Each row listens to its own counter, so a bump rebuilds only its row.
class ActivityScreen extends StatefulWidget {
  const new({required this.catalogue, required this.source, super.key});

  final Catalogue catalogue;
  final ActivitySource source;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final List<ValueNotifier<int>> _counts = [
    for (var i = 0; i < widget.source.counters; i++) ValueNotifier(0),
  ];
  late final StreamSubscription<List<Bump>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.source.events().listen(_apply);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    for (final count in _counts) {
      count.dispose();
    }
    super.dispose();
  }

  void _apply(List<Bump> bumps) {
    for (final bump in bumps) {
      _counts[bump.index].value += bump.amount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('activity-list'),
      itemCount: _counts.length,
      itemBuilder: (context, index) => _CounterRow(
        item: widget.catalogue.items[index],
        count: _counts[index],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const new({required this.item, required this.count});

  final Item item;
  final ValueListenable<int> count;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: count,
      builder: (context, value, _) => ListTile(
        key: Key('counter-${item.id}'),
        leading: SizedBox.square(dimension: 40, child: ItemArt(item: item)),
        title: Text(item.title),
        subtitle: LinearProgressIndicator(value: value % 100 / 100),
        trailing: Text('$value', key: Key('count-${item.id}')),
      ),
    );
  }
}
