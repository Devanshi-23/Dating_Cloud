import '../errors/failure.dart';

typedef Json = Map<String, dynamic>;

Failure _malformed(String field) => Failure(
  ErrorCode.serverError,
  message: 'The server sent an unexpected response ($field).',
);

Json asJson(Object? value, [String field = 'body']) {
  if (value is Map) return value.cast<String, dynamic>();
  throw _malformed(field);
}

List<Json> asJsonList(Object? value, [String field = 'items']) {
  if (value is List) return [for (final item in value) asJson(item, field)];
  throw _malformed(field);
}

extension JsonRead on Json {
  T req<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw _malformed(key);
  }

  T? opt<T>(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is T) return value;
    throw _malformed(key);
  }

  int reqInt(String key) => req<num>(key).toInt();

  double? optDouble(String key) => opt<num>(key)?.toDouble();

  DateTime reqDate(String key) {
    final parsed = DateTime.tryParse(req<String>(key));
    if (parsed == null) throw _malformed(key);
    return parsed;
  }

  DateTime? optDate(String key) {
    final raw = opt<String>(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw) ?? (throw _malformed(key));
  }

  List<String> stringList(String key) =>
      (opt<List<dynamic>>(key) ?? const []).whereType<String>().toList();
}
