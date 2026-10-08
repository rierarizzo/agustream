import 'package:flutter/foundation.dart';

import '../../domain/backend/account_repository.dart';
import '../../domain/backend/backend_profile.dart';
import '../../domain/backend/backend_session.dart';
import 'nuvio_client.dart';

/// [AccountRepository] backed by a Nuvio (Supabase) deployment.
class NuvioAccountRepository extends ChangeNotifier
    implements AccountRepository {
  NuvioAccountRepository(this._client);

  final NuvioClient _client;

  List<BackendProfile> _profiles = const <BackendProfile>[];
  BackendProfile? _activeProfile;
  Object? _profilesError;
  bool _isLoadingProfiles = false;

  @override
  Listenable get changes => this;

  @override
  BackendSession? get session => _client.session;

  @override
  bool get isSignedIn => _client.session != null;

  @override
  String? get email => _client.session?.email;

  @override
  List<BackendProfile> get profiles => _profiles;

  @override
  bool get isLoadingProfiles => _isLoadingProfiles;

  @override
  Object? get profilesError => _profilesError;

  @override
  BackendProfile? get activeProfile => _activeProfile;

  @override
  Future<BackendSession> signIn({
    required String email,
    required String password,
  }) async {
    final session = await _client.signIn(email: email, password: password);
    _activeProfile = null;
    _profiles = const <BackendProfile>[];
    _profilesError = null;
    notifyListeners();

    // Loaded here so the profile picker has something to show right away. A
    // failure is captured, never thrown: the session is valid either way.
    await loadProfiles();
    return session;
  }

  @override
  Future<void> signOut() async {
    await _client.signOut();
    _profiles = const <BackendProfile>[];
    _activeProfile = null;
    _profilesError = null;
    notifyListeners();
  }

  @override
  Future<void> loadProfiles() async {
    if (!isSignedIn) return;
    _isLoadingProfiles = true;
    _profilesError = null;
    notifyListeners();
    try {
      final rows = await _client.select('profiles', order: 'profile_index.asc');
      _profiles = rows.map(BackendProfile.fromJson).toList(growable: false);
    } on Exception catch (error) {
      _profiles = const <BackendProfile>[];
      _profilesError = error;
    } finally {
      _isLoadingProfiles = false;
    }
    notifyListeners();
  }

  @override
  Future<void> selectProfile(BackendProfile profile) async {
    if (profile.profileId == _activeProfile?.profileId) return;
    _activeProfile = profile;
    notifyListeners();
  }
}
