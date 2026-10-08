import 'package:agustream/domain/backend/backend_connection.dart';
import 'package:agustream/domain/backend/backend_profile.dart';
import 'package:agustream/domain/backend/backend_provider.dart';
import 'package:agustream/domain/backend/backend_session.dart';
import 'package:agustream/domain/backend/library_item.dart';
import 'package:agustream/domain/backend/watch_progress.dart';

/// In-memory [BackendProvider] for widget tests.
///
/// The screens only depend on the interface, so this replaces the HTTP client
/// and lets tests describe a library without touching the network.
class FakeBackendProvider implements BackendProvider {
  FakeBackendProvider({
    this.items = const <LibraryItem>[],
    this.progress = const <WatchProgress>[],
    bool signedIn = true,
    this.failure,
  }) : _session = signedIn
           ? const BackendSession(
               accessToken: 'test-token',
               refreshToken: 'test-refresh',
               userId: 'test-user',
               email: 'tester@example.com',
             )
           : null;

  final List<LibraryItem> items;
  final List<WatchProgress> progress;

  /// When set, every data read throws it.
  final Object? failure;

  BackendSession? _session;

  /// Number of times the library has been fetched.
  int libraryFetches = 0;

  @override
  BackendConnection? get connection => null;

  @override
  BackendSession? get session => _session;

  @override
  bool get isSignedIn => _session != null;

  @override
  Future<BackendConnection> discover() async {
    throw UnimplementedError('FakeBackendProvider.discover');
  }

  @override
  Future<BackendSession> signIn({
    required String email,
    required String password,
  }) async {
    return _session = BackendSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      userId: 'test-user',
      email: email,
    );
  }

  @override
  Future<void> signOut() async {
    _session = null;
  }

  @override
  Future<List<BackendProfile>> fetchProfiles() async =>
      const <BackendProfile>[];

  @override
  Future<List<LibraryItem>> fetchLibrary() async {
    libraryFetches++;
    final error = failure;
    if (error != null) throw error;
    return items;
  }

  @override
  Future<List<WatchProgress>> fetchWatchProgress() async {
    final error = failure;
    if (error != null) throw error;
    return progress;
  }
}

/// Builds a [LibraryItem] with just the fields the grid uses.
LibraryItem libraryItem({
  required String id,
  required String name,
  String contentType = 'movie',
  String? poster,
  String? releaseInfo,
}) {
  return LibraryItem(
    id: id,
    contentId: id,
    contentType: contentType,
    name: name,
    poster: poster,
    releaseInfo: releaseInfo,
  );
}
