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

  BackendProfile? _activeProfile;

  @override
  Listenable get changes => this;

  @override
  BackendSession? get session => _client.session;

  @override
  bool get isSignedIn => _client.session != null;

  @override
  String? get email => _client.session?.email;

  @override
  BackendProfile? get activeProfile => _activeProfile;

  @override
  Future<BackendSession> signIn({
    required String email,
    required String password,
  }) async {
    final session = await _client.signIn(email: email, password: password);
    _activeProfile = null;
    notifyListeners();
    return session;
  }

  @override
  Future<void> signOut() async {
    await _client.signOut();
    _activeProfile = null;
    notifyListeners();
  }

  @override
  Future<List<BackendProfile>> profiles() async {
    final rows = await _client.select('profiles', order: 'profile_index.asc');
    return rows.map(BackendProfile.fromJson).toList(growable: false);
  }

  @override
  Future<void> selectProfile(BackendProfile profile) async {
    if (profile.profileId == _activeProfile?.profileId) return;
    _activeProfile = profile;
    notifyListeners();
  }
}
