import 'dart:convert';
import 'dart:io';

/// A tiny JSON-array document store backed by a file.
///
/// Used by the local backend (`data/local/`) to persist its rows. A missing or
/// corrupt file reads as empty instead of throwing, so the app degrades to "no
/// data" rather than failing to start.
class JsonFileStore {
  const JsonFileStore(this.path);

  /// Absolute path of the backing file.
  final String path;

  Future<List<Map<String, dynamic>>> read() async {
    try {
      final file = File(path);
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: false);
    } on Exception {
      return const [];
    }
  }

  Future<void> write(List<Map<String, dynamic>> rows) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(rows), flush: true);
    } on Exception {
      // Best effort: a write that cannot be persisted does not crash the app.
    }
  }
}
