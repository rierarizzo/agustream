import 'dart:convert';
import 'dart:io';

/// A JSON-object document store backed by a file.
///
/// A missing or corrupt file reads as `{}` instead of throwing, so the app
/// degrades to "no data" rather than failing to start.
class JsonMapStore {
  const JsonMapStore(this.path);

  /// Absolute path of the backing file.
  final String path;

  Future<Map<String, dynamic>> read() async {
    try {
      final file = File(path);
      if (!await file.exists()) return <String, dynamic>{};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? decoded.cast<String, dynamic>() : <String, dynamic>{};
    } on Exception {
      return <String, dynamic>{};
    }
  }

  Future<void> write(Map<String, dynamic> data) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(data), flush: true);
    } on Exception {
      // Best effort.
    }
  }
}
