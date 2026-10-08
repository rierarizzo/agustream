import 'package:agustream/domain/backend/account_repository.dart';
import 'package:agustream/domain/backend/backend_profile.dart';
import 'package:agustream/domain/backend/backend_session.dart';
import 'package:agustream/domain/backend/library_item.dart';
import 'package:agustream/domain/backend/library_repository.dart';
import 'package:agustream/domain/backend/progress_repository.dart';
import 'package:agustream/domain/backend/watch_progress.dart';
import 'package:flutter/foundation.dart';

/// In-memory account for widget tests.
class FakeAccountRepository extends ChangeNotifier
    implements AccountRepository {
  FakeAccountRepository({bool signedIn = true, this.availableProfiles = const []})
    : _session = signedIn
          ? const BackendSession(
              accessToken: 'test-token',
              refreshToken: 'test-refresh',
              userId: 'test-user',
              email: 'tester@example.com',
            )
          : null;

  /// Profiles returned by [profiles].
  final List<BackendProfile> availableProfiles;

  BackendSession? _session;
  BackendProfile? _activeProfile;

  @override
  Listenable get changes => this;

  @override
  BackendSession? get session => _session;

  @override
  bool get isSignedIn => _session != null;

  @override
  String? get email => _session?.email;

  @override
  BackendProfile? get activeProfile => _activeProfile;

  @override
  Future<BackendSession> signIn({
    required String email,
    required String password,
  }) async {
    final session = BackendSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      userId: 'test-user',
      email: email,
    );
    _session = session;
    notifyListeners();
    return session;
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _activeProfile = null;
    notifyListeners();
  }

  @override
  Future<List<BackendProfile>> profiles() async => availableProfiles;

  @override
  Future<void> selectProfile(BackendProfile profile) async {
    _activeProfile = profile;
    notifyListeners();
  }
}

/// In-memory library for widget tests.
class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository({this.items = const <LibraryItem>[], this.failure});

  final List<LibraryItem> items;

  /// When set, [all] throws it.
  final Object? failure;

  /// Number of times the library has been read.
  int reads = 0;

  @override
  Future<List<LibraryItem>> all() async {
    reads++;
    final error = failure;
    if (error != null) throw error;
    return items;
  }
}

/// In-memory progress for widget tests.
class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({this.entries = const <WatchProgress>[], this.failure});

  final List<WatchProgress> entries;

  /// When set, [all] throws it.
  final Object? failure;

  @override
  Future<List<WatchProgress>> all() async {
    final error = failure;
    if (error != null) throw error;
    return entries;
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
