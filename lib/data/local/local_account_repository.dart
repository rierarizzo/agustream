import 'package:flutter/foundation.dart';

import '../../domain/backend/account_repository.dart';
import '../../domain/backend/backend_profile.dart';

/// [AccountRepository] for local mode: there is always a session and there are
/// no profiles, because the data lives on this machine.
///
/// This is what makes "todo local" possible without inventing a fake account:
/// [requiresProfile] is `false`, so the app never shows the profile picker.
class LocalAccountRepository extends ChangeNotifier
    implements AccountRepository {
  @override
  bool get isSignedIn => true;

  @override
  String? get email => null;

  @override
  bool get requiresProfile => false;

  @override
  List<BackendProfile> get profiles => const <BackendProfile>[];

  @override
  bool get isLoadingProfiles => false;

  @override
  Object? get profilesError => null;

  @override
  BackendProfile? get activeProfile => null;

  @override
  Listenable get changes => this;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<bool> restoreSession() async => true;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> loadProfiles() async {}

  @override
  Future<void> selectProfile(BackendProfile profile) async {}
}
