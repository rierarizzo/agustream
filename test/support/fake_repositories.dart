import 'package:agustream/domain/addons/catalog_repository.dart';
import 'package:agustream/domain/addons/meta.dart';
import 'package:agustream/domain/addons/metadata_repository.dart';
import 'package:agustream/domain/addons/stream_repository.dart';
import 'package:agustream/domain/backend/account_repository.dart';
import 'package:agustream/domain/backend/addon.dart';
import 'package:agustream/domain/backend/addon_repository.dart';
import 'package:agustream/domain/backend/backend_profile.dart';
import 'package:agustream/domain/backend/library_item.dart';
import 'package:agustream/domain/backend/library_repository.dart';
import 'package:agustream/domain/backend/progress_repository.dart';
import 'package:agustream/domain/backend/rating_repository.dart';
import 'package:agustream/domain/backend/watch_progress.dart';
import 'package:agustream/domain/backend/watched_entry.dart';
import 'package:flutter/foundation.dart';

/// Profile the fakes use when a test does not care about profiles.
const BackendProfile testProfile = BackendProfile(
  id: 'prof-1',
  name: 'Tester',
  profileId: 1,
);

/// In-memory account for widget tests.
class FakeAccountRepository extends ChangeNotifier
    implements AccountRepository {
  FakeAccountRepository({
    bool signedIn = true,
    bool withProfile = true,
    this.requiresProfile = true,
    this.availableProfiles = const <BackendProfile>[testProfile],
    this.profilesError,
    this.isLoadingProfiles = false,
  }) : _isSignedIn = signedIn,
       _email = signedIn ? 'tester@example.com' : null {
    _profiles = availableProfiles;
    if (signedIn && withProfile && availableProfiles.isNotEmpty) {
      _activeProfile = availableProfiles.first;
    }
  }

  /// Profiles the account reports.
  final List<BackendProfile> availableProfiles;

  /// Whether the app must wait for a profile before showing content.
  @override
  final bool requiresProfile;

  /// Reported by [profilesError] without needing a failed load.
  @override
  final Object? profilesError;

  @override
  final bool isLoadingProfiles;

  bool _isSignedIn;
  String? _email;
  List<BackendProfile> _profiles = const <BackendProfile>[];
  BackendProfile? _activeProfile;

  @override
  Listenable get changes => this;

  @override
  bool get isSignedIn => _isSignedIn;

  @override
  String? get email => _email;

  @override
  List<BackendProfile> get profiles => _profiles;

  @override
  BackendProfile? get activeProfile => _activeProfile;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isSignedIn = true;
    _email = email;
    // Signing in does not choose a profile: the app asks for one.
    _activeProfile = null;
    _profiles = availableProfiles;
    notifyListeners();
  }

  @override
  Future<bool> restoreSession() async => _isSignedIn;

  @override
  Future<void> signOut() async {
    _isSignedIn = false;
    _email = null;
    _profiles = const <BackendProfile>[];
    _activeProfile = null;
    notifyListeners();
  }

  @override
  Future<void> loadProfiles() async {
    _profiles = availableProfiles;
    notifyListeners();
  }

  @override
  Future<void> selectProfile(BackendProfile profile) async {
    if (profile.profileId == _activeProfile?.profileId) return;
    _activeProfile = profile;
    notifyListeners();
  }
}

/// In-memory library for widget tests.
class FakeLibraryRepository extends ChangeNotifier
    implements LibraryRepository {
  FakeLibraryRepository({
    List<LibraryItem> items = const <LibraryItem>[],
    this.failure,
  }) : _items = [...items];

  final List<LibraryItem> _items;

  /// When set, every method throws it.
  final Object? failure;

  /// Number of times the library has been read.
  int reads = 0;

  /// Current contents.
  List<LibraryItem> get items => List.unmodifiable(_items);

  @override
  Listenable get changes => this;

  @override
  Future<List<LibraryItem>> all() async {
    reads++;
    _throwIfFailing();
    return _items;
  }

  @override
  Future<bool> contains(String contentId) async {
    _throwIfFailing();
    return _items.any((item) => item.contentId == contentId);
  }

  @override
  Future<void> add(LibraryItem item) async {
    _throwIfFailing();
    if (_items.any((existing) => existing.contentId == item.contentId)) return;
    _items.add(item);
    notifyListeners();
  }

  @override
  Future<void> remove(String contentId) async {
    _throwIfFailing();
    _items.removeWhere((item) => item.contentId == contentId);
    notifyListeners();
  }

  void _throwIfFailing() {
    final error = failure;
    if (error != null) throw error;
  }
}

/// In-memory progress for widget tests.
class FakeProgressRepository extends ChangeNotifier
    implements ProgressRepository {
  FakeProgressRepository({
    List<WatchProgress> entries = const <WatchProgress>[],
    Set<String> watched = const <String>{},
    List<WatchedEntry> watchedHistory = const <WatchedEntry>[],
    this.failure,
  }) : _entries = [...entries],
       _watched = {...watched},
       _watchedHistory = [...watchedHistory];

  final List<WatchProgress> _entries;

  /// Content ids reported as title-level watched markers (movies).
  final Set<String> _watched;

  /// Extra watched-history rows (episodes), for completed-series tests.
  final List<WatchedEntry> _watchedHistory;

  /// Marks [contentId] as watched (or not) for the current run.
  void setWatched(String contentId, bool isWatched) {
    if (isWatched) {
      _watched.add(contentId);
    } else {
      _watched.remove(contentId);
    }
    notifyListeners();
  }

  /// When set, every method throws it.
  final Object? failure;

  /// Current entries.
  List<WatchProgress> get entries => List.unmodifiable(_entries);

  @override
  Listenable get changes => this;

  @override
  Future<List<WatchProgress>> all() async {
    _throwIfFailing();
    return _entries;
  }

  @override
  Future<List<WatchedEntry>> watchedEntries(
    Iterable<String> candidateIds,
  ) async {
    _throwIfFailing();
    final candidates = candidateIds.toSet();
    return [
      for (final id in _watched)
        if (candidates.contains(id))
          WatchedEntry(contentId: id, contentType: 'movie'),
      for (final entry in _watchedHistory)
        if (candidates.contains(entry.contentId)) entry,
    ];
  }

  @override
  Future<void> markWatched({
    required String contentId,
    required String contentType,
    int? season,
    int? episode,
  }) async {
    _throwIfFailing();
    if (season == null && episode == null) {
      _watched.add(contentId);
    } else {
      _watchedHistory.add(
        WatchedEntry(
          contentId: contentId,
          contentType: contentType,
          season: season,
          episode: episode,
        ),
      );
    }
    notifyListeners();
  }

  @override
  Future<void> unmarkWatched({
    required String contentId,
    int? season,
    int? episode,
  }) async {
    _throwIfFailing();
    _watched.remove(contentId);
    _watchedHistory.removeWhere(
      (entry) =>
          entry.contentId == contentId &&
          entry.season == season &&
          entry.episode == episode,
    );
    notifyListeners();
  }

  @override
  Future<void> save(WatchProgress progress) async {
    _throwIfFailing();
    final key = progress.progressKey ?? _key(progress.contentId, progress.videoId);
    _entries.removeWhere(
      (entry) =>
          (entry.progressKey ?? _key(entry.contentId, entry.videoId)) == key,
    );
    _entries.add(progress);
    notifyListeners();
  }

  static String _key(String contentId, String? videoId) =>
      '$contentId|${videoId ?? ''}';

  void _throwIfFailing() {
    final error = failure;
    if (error != null) throw error;
  }
}

/// In-memory metadata for widget tests.
class FakeMetadataRepository implements MetadataRepository {
  FakeMetadataRepository({
    this.detailResult,
    this.similarResult = const <MetaPreview>[],
    this.detailFailure,
  });

  /// Returned by [detail] when set.
  final MetaDetail? detailResult;

  /// Returned by [similar].
  final List<MetaPreview> similarResult;

  /// When set, [detail] throws it.
  final Object? detailFailure;

  /// Number of times the metadata has been read.
  int detailReads = 0;

  @override
  Future<MetaDetail?> detail({
    required String type,
    required String id,
  }) async {
    detailReads++;
    final error = detailFailure;
    if (error != null) throw error;
    return detailResult;
  }

  @override
  Future<List<MetaPreview>> similar({
    required String type,
    required String id,
    String? genre,
  }) async {
    return similarResult;
  }
}

/// In-memory catalogs for widget tests.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    this.catalogsResult = const <CatalogRef>[],
    this.itemsResult = const <MetaPreview>[],
    this.itemsBySkip,
    this.failure,
  });

  final List<CatalogRef> catalogsResult;
  final List<MetaPreview> itemsResult;

  /// When set, [items] returns the page for the requested `skip` offset.
  final Map<int, List<MetaPreview>>? itemsBySkip;

  /// When set, both methods throw it.
  final Object? failure;

  @override
  Future<List<CatalogRef>> catalogs() async {
    final error = failure;
    if (error != null) throw error;
    return catalogsResult;
  }

  @override
  Future<List<MetaPreview>> items(
    CatalogRef ref, {
    Map<String, String>? extra,
  }) async {
    final error = failure;
    if (error != null) throw error;
    final bySkip = itemsBySkip;
    if (bySkip == null) return itemsResult;
    final skip = int.tryParse(extra?['skip'] ?? '0') ?? 0;
    return bySkip[skip] ?? const <MetaPreview>[];
  }
}

/// In-memory streams for widget tests.
class FakeStreamRepository implements StreamRepository {
  FakeStreamRepository({this.groups = const <StreamGroup>[], this.failure});

  final List<StreamGroup> groups;

  /// When set, [all] throws it.
  final Object? failure;

  /// Number of times the streams have been read.
  int reads = 0;

  @override
  Future<List<StreamGroup>> all({
    required String type,
    required String id,
  }) async {
    reads++;
    final error = failure;
    if (error != null) throw error;
    return groups;
  }
}

/// In-memory ratings for widget tests.
class FakeRatingRepository implements RatingRepository {
  FakeRatingRepository({Map<String, int>? ratings}) : _ratings = {...?ratings};

  final Map<String, int> _ratings;

  @override
  Future<int?> ratingOf(String contentId) async => _ratings[contentId];

  @override
  Future<void> setRating(String contentId, int? rating) async {
    if (rating == null) {
      _ratings.remove(contentId);
    } else {
      _ratings[contentId] = rating;
    }
  }
}

/// In-memory addons for tests.
class FakeAddonRepository implements AddonRepository {
  FakeAddonRepository({this.addons = const <Addon>[], this.failure});

  final List<Addon> addons;

  /// When set, [all] throws it.
  final Object? failure;

  @override
  Future<List<Addon>> all() async {
    final error = failure;
    if (error != null) throw error;
    return addons;
  }
}

/// Builds a [LibraryItem] with just the fields the grid uses.
LibraryItem libraryItem({
  required String id,
  required String name,
  String contentType = 'movie',
  String? poster,
  String? releaseInfo,
  String? addonBaseUrl,
}) {
  return LibraryItem(
    id: id,
    contentId: id,
    contentType: contentType,
    name: name,
    poster: poster,
    releaseInfo: releaseInfo,
    addonBaseUrl: addonBaseUrl,
  );
}
