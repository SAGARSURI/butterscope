import 'package:butterscope_sample/src/activity/activity_screen.dart';
import 'package:butterscope_sample/src/activity/activity_source.dart';
import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/feed/feed_screen.dart';
import 'package:butterscope_sample/src/gallery/gallery_screen.dart';
import 'package:butterscope_sample/src/inbox/inbox_screen.dart';
import 'package:butterscope_sample/src/inbox/inbox_socket.dart';
import 'package:butterscope_sample/src/search/search_screen.dart';
import 'package:flutter/material.dart';

/// The app's top level: a bottom bar that switches between screens.
///
/// Only the selected screen is built, so a screen's work stops when the
/// user leaves it.
class HomeShell extends StatefulWidget {
  const new({
    required this.catalogue,
    required this.activity,
    required this.inbox,
    super.key,
  });

  final Catalogue catalogue;
  final ActivitySource activity;
  final InboxSocket inbox;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;

  static const _titles = ['Feed', 'Search', 'Activity', 'Inbox', 'Gallery'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selected])),
      body: SafeArea(
        child: switch (_selected) {
          0 => FeedScreen(catalogue: widget.catalogue),
          1 => SearchScreen(catalogue: widget.catalogue),
          2 => ActivityScreen(
            catalogue: widget.catalogue,
            source: widget.activity,
          ),
          3 => InboxScreen(socket: widget.inbox),
          _ => const GalleryScreen(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (index) => setState(() => _selected = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.view_agenda), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
          NavigationDestination(
            icon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
        ],
      ),
    );
  }
}
