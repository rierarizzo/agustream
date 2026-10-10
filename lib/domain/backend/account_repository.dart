import 'package:flutter/foundation.dart';

import 'backend_profile.dart';

/// Account-level access: the session and the profiles behind it.
///
/// Observable — [changes] fires when the session, the profile list or the
/// active profile changes, so screens can react instead of polling.
/// `Listenable` comes from `package:flutter/foundation.dart`, which is neither
/// UI nor network.
///
/// Session tokens are deliberately **not** part of this contract: they are
/// transport details of whichever backend is in use. The UI only needs to know
/// whether there is a session and, optionally, an email.
abstract interface class AccountRepository {
  /// Whether there is a signed-in session.
  bool get isSignedIn;

  /// Email of the signed-in user, when the backend reports one.
  String? get email;

  /// Whether content reads are scoped to a profile that must be chosen first.
  ///
  /// Backends without profiles return `false`: the app is usable right after
  /// sign-in and never shows a profile picker.
  bool get requiresProfile;

  /// Profiles of the signed-in account. Empty when the backend has none.
  List<BackendProfile> get profiles;

  /// `true` while [loadProfiles] is in flight.
  bool get isLoadingProfiles;

  /// Failure of the last profile load, or `null`.
  Object? get profilesError;

  /// Profile that library, progress and every write are scoped to.
  ///
  /// `null` means "not chosen yet". When [requiresProfile] is `true` it has
  /// **no default**: the app asks for a profile instead of guessing, because a
  /// write saved to the wrong profile would be wrong data, not merely missing.
  BackendProfile? get activeProfile;

  /// Fires when the session, [profiles] or [activeProfile] changes.
  Listenable get changes;

  /// Signs in with email + password and loads the profiles.
  ///
  /// A profile load failure does not undo the session: it is reported through
  /// [profilesError] so the UI can offer a retry.
  Future<void> signIn({required String email, required String password});

  /// Restores a previously persisted session, if there is one.
  ///
  /// Returns `true` when a usable session is available; `false` means the
  /// caller should ask for a sign-in. Implementations without persistence can
  /// simply return `false`.
  Future<bool> restoreSession();

  /// Drops the session, invalidating it on the backend when possible.
  Future<void> signOut();

  /// (Re)loads [profiles] for the signed-in account.
  Future<void> loadProfiles();

  /// Chooses the profile to work with.
  Future<void> selectProfile(BackendProfile profile);
}
