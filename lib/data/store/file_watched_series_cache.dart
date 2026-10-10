import 'dart:convert';
import 'dart:io';

import '../../domain/backend/watched_series_cache.dart';
import 'app_paths.dart';

/// [WatchedSeriesCache] stored as a JSON file.
///
/// Shape: `{ "<profileKey>": { "<seriesId>": { "s": "<signature>", "w": true } } }`.
/// Read and writes are best effort: a broken file degrades to "no cache" (so the
/// series are recomputed) instead of failing.
class FileWatchedSeriesCache implements WatchedSeriesCache {
  FileWatchedSeriesCache({String? path})
    : path = path ?? watchedSeriesCachePath();

  /// Absolute path of the backing file.
  final String path;

  Map<String, dynamic>? _data;

  Future<Map<String, dynamic>> _load() async {
    final cached = _data;
    if (cached != null) return cached;
    try {
      final file = File(path);
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        return _data = decoded is Map ? decoded.cast<String, dynamic>() : {};
      }
    } on Exception {
      // Fall through to an empty cache.
    }
    return _data = <String, dynamic>{};
  }

  Future<void> _save() async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_data ?? const {}), flush: true);
    } on Exception {
      // Best effort.
    }
  }

  @override
  Future<CachedSeriesState?> read(String profileKey, String seriesId) async {
    final profile = (await _load())[profileKey];
    if (profile is! Map) return null;
    final entry = profile[seriesId];
    if (entry is! Map) return null;
    final signature = entry['s'];
    final watched = entry['w'];
    if (signature is! String || watched is! bool) return null;
    return CachedSeriesState(signature: signature, watched: watched);
  }

  @override
  Future<void> write(
    String profileKey,
    String seriesId,
    CachedSeriesState state,
  ) => writeAll(profileKey, {seriesId: state});

  @override
  Future<void> writeAll(
    String profileKey,
    Map<String, CachedSeriesState> states,
  ) async {
    if (states.isEmpty) return;
    final data = await _load();
    final profile =
        (data[profileKey] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    for (final entry in states.entries) {
      profile[entry.key] = {'s': entry.value.signature, 'w': entry.value.watched};
    }
    data[profileKey] = profile;
    await _save();
  }

  @override
  Future<void> clear(String profileKey) async {
    final data = await _load();
    data.remove(profileKey);
    await _save();
  }
}
