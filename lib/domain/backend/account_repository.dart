import 'package:flutter/foundation.dart';

import 'backend_profile.dart';
import 'backend_session.dart';

/// Account-level access: the session and the profiles behind it.
///
/// Observable — [changes] fires when the session or the active profile
/// changes, so screens can reload instead of polling. `Listenable` comes from
/// `package:flutter/foundation.dart`, which is neither UI nor network.
abstract interface class AccountRepository {
  /// Signed-in session, or `null`.
  BackendSession? get session;

  bool get isSignedIn;

  /// Email of the signed-in user, when the backend reports one.
  String? get email;

  /// Profile that library and progress are scoped to.
  ///
  /// `null` until one is selected, which means "no scope" — reads then return
  /// everything the account is allowed to see.
  BackendProfile? get activeProfile;

  /// Fires when the session or [activeProfile] changes.
  Listenable get changes;

  /// Signs in with email + password.
  Future<BackendSession> signIn({
    required String email,
    required String password,
  });

  /// Drops the session, invalidating it on the backend when possible.
  Future<void> signOut();

  /// Profiles of the signed-in account.
  Future<List<BackendProfile>> profiles();

  /// Switches the active profile.
  Future<void> selectProfile(BackendProfile profile);
}
