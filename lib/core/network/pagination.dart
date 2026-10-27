import 'json.dart';

/// Cursor-paginated list. `nextCursor == null` means there are no more pages.
class Paginated<T> {
  const Paginated({required this.items, this.nextCursor});

  const Paginated.empty() : items = const [], nextCursor = null;

  /// Parses `{ "items": [...], "nextCursor": "..." }`.
  factory Paginated.fromJson(Object? data, T Function(Json json) parseItem) {
    final json = asJson(data, 'page');
    return Paginated(
      items: [for (final item in asJsonList(json['items'])) parseItem(item)],
      nextCursor: json.opt<String>('nextCursor'),
    );
  }

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

class PageRequest {
  const PageRequest({this.cursor, this.limit = 20})
    : assert(limit > 0 && limit <= 50);

  final String? cursor;
  final int limit;

  Map<String, dynamic> toQuery() => {
    'limit': limit,
    if (cursor != null) 'cursor': cursor,
  };
}
