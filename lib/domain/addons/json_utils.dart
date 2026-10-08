/// Small, defensive JSON coercion helpers shared by the addon models.
///
/// They are intentionally lenient: addon payloads are third-party data, so a
/// malformed field should degrade to `null`/empty instead of throwing a cast
/// error and taking the whole response down.
library;

/// Returns [value] as a `List<String>`, ignoring non-string entries.
List<String> stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

/// Returns [value] as an `int`, accepting numeric strings.
int? toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Returns [value] as a `double`, accepting numeric strings.
double? toDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Casts [value] to a JSON object, or returns `null` if it is not one.
Map<String, dynamic>? toJsonObject(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : null;
