import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/detail/detail_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/plant_costs.dart';
import 'package:butterscope_sample/src/plants/screen_plants.dart';
import 'package:butterscope_sample/src/widgets/item_tile.dart';
import 'package:flutter/material.dart';

/// A search field that filters the catalogue as the user types.
class SearchScreen extends StatefulWidget {
  const new({required this.catalogue, super.key});

  final Catalogue catalogue;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Item> _results = const [];
  String _query = '';

  void _search(String query) {
    setState(() {
      _query = query;
      _results = PlantScope.of(context) == Plant.uiBusy
          ? fuzzySearch(
              widget.catalogue,
              query,
              words: uiBusyWordsPerItem.value,
            )
          : widget.catalogue.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: const Key('search-field'),
            decoration: const InputDecoration(
              hintText: 'Search items or tags',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _search,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _query.trim().isEmpty ? '' : '${_results.length} results',
              key: const Key('search-count'),
            ),
          ),
        ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    return ListView.builder(
      key: const Key('search-results'),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return ItemTile(
          item: item,
          onTap: () => openDetail(context, widget.catalogue, item),
        );
      },
    );
  }
}
