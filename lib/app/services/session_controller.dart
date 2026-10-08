import 'package:flutter/foundation.dart';

import '../../domain/backend/backend_provider.dart';

/// Observable sign-in state.
///
/// [BackendProvider] is a plain interface with no change notification, so this
/// wraps it: screens that only work with a session (the library, for example)
/// listen here and reload when the session appears or goes away.
class SessionController extends ChangeNotifier {
  SessionController(this._backend);

  final BackendProvider _backend;

  bool get isSignedIn => _backend.isSignedIn;

  /// Email of the signed-in user, when the backend reports one.
  String? get email => _backend.session?.email;

  Future<void> signIn({required String email, required String password}) async {
    await _backend.signIn(email: email, password: password);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _backend.signOut();
    notifyListeners();
  }
}
