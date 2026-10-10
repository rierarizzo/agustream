import 'package:flutter/foundation.dart';

/// App-level chrome state the shell reacts to.
///
/// The player asks for immersive mode while it is open, so the navigation rail
/// is hidden even when the window is not fullscreen (the title bar stays, so the
/// window can still be moved or closed).
abstract final class AppChrome {
  /// `true` while the app chrome should be hidden.
  static final ValueNotifier<bool> immersive = ValueNotifier<bool>(false);

  static int _requests = 0;

  /// Hides the chrome until the matching [exitImmersive].
  ///
  /// Counted, so when a player replaces another one (autoplay) the chrome does
  /// not flash back during the transition.
  static void enterImmersive() {
    _requests++;
    immersive.value = true;
  }

  /// Releases one immersive request.
  static void exitImmersive() {
    if (_requests > 0) _requests--;
    immersive.value = _requests > 0;
  }
}
