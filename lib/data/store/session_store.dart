import 'dart:convert';
import 'dart:io';

/// Persistence for the signed-in session.
///
/// Kept behind an interface so the transport does not know where the session
/// lives: tests and `--no-persist` runs use [NoopSessionStore], while the app
/// uses [FileSessionStore].
abstract interface class SessionStore {
  /// Returns the stored session, or `null` when there is none.
  Future<Map<String, dynamic>?> read();

  /// Stores [session], replacing whatever was there.
  Future<void> write(Map<String, dynamic> session);

  /// Removes the stored session.
  Future<void> clear();
}

/// Store that keeps nothing. The session lives only in memory.
class NoopSessionStore implements SessionStore {
  const NoopSessionStore();

  @override
  Future<Map<String, dynamic>?> read() async => null;

  @override
  Future<void> write(Map<String, dynamic> session) async {}

  @override
  Future<void> clear() async {}
}

/// Stores the session as a JSON file under the user's config directory.
///
/// Failures are swallowed: a corrupted or unreadable file degrades to "no
/// session", which means signing in again, instead of crashing the startup.
class FileSessionStore implements SessionStore {
  FileSessionStore({String? path}) : path = path ?? _defaultPath();

  /// Absolute path of the session file.
  final String path;

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> session) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(session), flush: true);
    } on Exception {
      // Best effort: a session that cannot be persisted still works in memory.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Exception {
      // Nothing to clean up.
    }
  }

  /// `%APPDATA%\Agustream\session.json` on Windows, XDG config elsewhere.
  static String _defaultPath() {
    final env = Platform.environment;
    final separator = Platform.pathSeparator;
    final base = Platform.isWindows
        ? (env['APPDATA'] ?? env['LOCALAPPDATA'] ?? '.')
        : (env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '.'}/.config');
    return '$base${separator}Agustream${separator}session.json';
  }
}
