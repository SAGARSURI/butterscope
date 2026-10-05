import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:flutter/material.dart';

/// An item with the given [id], [title] and [tags], and fixed values for
/// the rest.
Item item(int id, String title, List<String> tags) {
  return Item(
    id: id,
    title: title,
    tags: tags,
    summary: 'Summary of $title.',
    rating: 4.5,
    saves: 7,
  );
}

/// Four items, small enough to work out every search by hand.
final smallCatalogue = Catalogue([
  item(0, 'Amber Lantern No. 1', ['outdoor', 'travel']),
  item(1, 'Quiet Harbour No. 2', ['indoor', 'gift']),
  item(2, 'Cedar Lantern No. 3', ['outdoor', 'handmade']),
  item(3, 'Silver Meadow No. 4', ['garden', 'outdoor']),
]);

/// Shows [screen] inside an app with a scaffold, as the home shell would,
/// in a build with [plant].
Widget inApp(Widget screen, {Plant plant = Plant.none}) {
  return PlantScope(
    plant: plant,
    child: MaterialApp(home: Scaffold(body: screen)),
  );
}
