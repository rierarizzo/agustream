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
import 'package:agustream/domain/backend/watch_progress.dart';
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
