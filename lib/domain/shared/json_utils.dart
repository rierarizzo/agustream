/// Small, defensive JSON coercion helpers shared by the domain models.
///
/// They are intentionally lenient: addon and backend payloads are third-party
/// data, so a malformed field should degrade to `null`/empty instead of throwing
/// a cast error and taking the whole response down.
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

/// Returns [value] as a `bool`, accepting `0`/`1` and `"true"`/`"false"`.
bool? toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return null;
}

/// Casts [value] to a JSON object, or returns `null` if it is not one.
Map<String, dynamic>? toJsonObject(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : null;

/// Converts an epoch-milliseconds value to a UTC [DateTime].
DateTime? toDateTimeMillis(Object? value) {
  final millis = toInt(value);
  return millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}

/// Converts a millisecond count to a [Duration].
Duration? toDurationMillis(Object? value) {
  final millis = toInt(value);
  return millis == null ? null : Duration(milliseconds: millis);
}
