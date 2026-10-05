import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/feed/feed_screen.dart';
import 'package:butterscope_sample/src/search/search_screen.dart';
import 'package:flutter/material.dart';

/// The app's top level: a bottom bar that switches between screens.
///
/// Only the selected screen is built, so a screen's work stops when the
/// user leaves it.
class HomeShell extends StatefulWidget {
  const new({required this.catalogue, super.key});

  final Catalogue catalogue;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;

  static const _titles = ['Feed', 'Search'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selected])),
      body: SafeArea(
        child: switch (_selected) {
          0 => FeedScreen(catalogue: widget.catalogue),
          _ => SearchScreen(catalogue: widget.catalogue),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (index) => setState(() => _selected = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.view_agenda), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        ],
      ),
    );
  }
}
