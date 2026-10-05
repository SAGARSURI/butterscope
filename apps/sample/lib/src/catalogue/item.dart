/// One entry in the catalogue.
class Item {
  const new({
    required this.id,
    required this.title,
    required this.tags,
    required this.summary,
    required this.rating,
    required this.saves,
  });

  /// Unique within a catalogue, and the item's position in it.
  final int id;

  final String title;

  /// Short labels, most specific first.
  final List<String> tags;

  /// A few sentences about the item.
  final String summary;

  /// From 1.0 to 5.0, in steps of 0.1.
  final double rating;

  /// How many people saved the item.
  final int saves;

  /// Whether [query] appears in the title or a tag, ignoring case.
  ///
  /// [query] must already be lower case.
  bool matches(String query) {
    if (title.toLowerCase().contains(query)) return true;
    return tags.any((tag) => tag.contains(query));
  }
}
