import 'backend_connection.dart';
import 'backend_profile.dart';
import 'backend_session.dart';
import 'library_item.dart';
import 'watch_progress.dart';

/// Abstraction over the Nuvio backend.
///
/// The README states that the backend is isolated behind this interface: if the
/// backend changes, only `lib/data/backend/` is replaced. Nothing in `ui/`
/// talks to the HTTP client directly.
abstract interface class BackendProvider {
  /// Discovery document, once [discover] has run.
  BackendConnection? get connection;

  /// Signed-in session, or `null`.
  BackendSession? get session;

  bool get isSignedIn;

  /// Fetches `<baseUrl>/.well-known/nuvio` and remembers the result.
  Future<BackendConnection> discover();

  /// Signs in with email + password.
  Future<BackendSession> signIn({
    required String email,
    required String password,
  });

  /// Drops the session, invalidating it on the backend when possible.
  Future<void> signOut();

  Future<List<BackendProfile>> fetchProfiles();

  Future<List<LibraryItem>> fetchLibrary();

  Future<List<WatchProgress>> fetchWatchProgress();
}

/// Thrown when a backend operation fails.
class BackendException implements Exception {
  const BackendException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'BackendException$status: $message';
  }
}
