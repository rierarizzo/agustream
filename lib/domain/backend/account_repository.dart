import 'package:flutter/foundation.dart';

import 'backend_profile.dart';
import 'backend_session.dart';

/// Account-level access: the session and the profiles behind it.
///
/// Observable — [changes] fires when the session, the profile list or the
/// active profile changes, so screens can react instead of polling.
/// `Listenable` comes from `package:flutter/foundation.dart`, which is neither
/// UI nor network.
abstract interface class AccountRepository {
  /// Signed-in session, or `null`.
  BackendSession? get session;

  bool get isSignedIn;

  /// Email of the signed-in user, when the backend reports one.
  String? get email;

  /// Profiles of the signed-in account. Empty until [loadProfiles] succeeds.
  List<BackendProfile> get profiles;

  /// `true` while [loadProfiles] is in flight.
  bool get isLoadingProfiles;

  /// Failure of the last profile load, or `null`.
  Object? get profilesError;

  /// Profile that library, progress and every write are scoped to.
  ///
  /// `null` means "not chosen yet". It has **no default**: the app asks for a
  /// profile instead of guessing, because a write saved to the wrong profile
  /// would be wrong data, not merely missing data.
  BackendProfile? get activeProfile;

  /// Fires when the session, [profiles] or [activeProfile] changes.
  Listenable get changes;

  /// Signs in with email + password and loads the profiles.
  ///
  /// A profile load failure does not undo the session: it is reported through
  /// [profilesError] so the UI can offer a retry.
  Future<BackendSession> signIn({
    required String email,
    required String password,
  });

  /// Drops the session, invalidating it on the backend when possible.
  Future<void> signOut();

  /// (Re)loads [profiles] for the signed-in account.
  Future<void> loadProfiles();

  /// Chooses the profile to work with.
  Future<void> selectProfile(BackendProfile profile);
}
