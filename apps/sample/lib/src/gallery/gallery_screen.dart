import 'package:flutter/material.dart';

/// How many cells the gallery shows. The six photos repeat.
const int galleryLength = 60;

/// [index]'s photo, one of six bundled 4032 x 3024 JPEGs, decoded no
/// wider than [width] logical pixels on this screen, so a 12 MP file
/// costs only what the cell shows.
Widget sizedPhoto(BuildContext context, int index, double width) {
  final pixels = (width * MediaQuery.devicePixelRatioOf(context)).ceil();
  return Image.asset(
    'assets/photos/photo_${index % 6 + 1}.jpg',
    key: Key('photo-$index'),
    cacheWidth: pixels,
    fit: BoxFit.cover,
    gaplessPlayback: true,
  );
}

/// A grid of photos; tapping one opens it full screen.
class GalleryScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The photos are 4:3 landscapes. Covering a square cell scales a
        // photo to the cell's height, so it is drawn 4/3 as wide as the
        // cell and is decoded at that width.
        final drawnWidth = constraints.maxWidth / 3 * 4 / 3;
        return GridView.builder(
          key: const Key('gallery-grid'),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: galleryLength,
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PhotoViewer(initialIndex: index),
              ),
            ),
            child: sizedPhoto(context, index, drawnWidth),
          ),
        );
      },
    );
  }
}

/// One photo at a time, full width; swipe for the next.
class PhotoViewer extends StatefulWidget {
  const new({required this.initialIndex, super.key});

  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          '${_index + 1} / $galleryLength',
          key: const Key('viewer-position'),
        ),
      ),
      body: PageView.builder(
        key: const Key('photo-viewer'),
        controller: _pages,
        itemCount: galleryLength,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) =>
            Center(child: sizedPhoto(context, index, width)),
      ),
    );
  }
}
