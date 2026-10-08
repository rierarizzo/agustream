import 'package:flutter/widgets.dart';

import '../../domain/backend/backend_provider.dart';
import 'session_controller.dart';

/// App-wide services, handed down the widget tree.
///
/// Screens read the backend from here instead of reaching into `data/`, which
/// keeps the `ui → domain → data` direction described in the README and lets
/// tests inject a fake [BackendProvider].
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.backend,
    required this.session,
    required super.child,
  });

  /// The Nuvio backend.
  final BackendProvider backend;

  /// Sign-in state, shared by every screen that needs a session.
  final SessionController session;

  static AppServices of(BuildContext context) {
    final services = context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(services != null, 'No AppServices found in the widget tree');
    return services!;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      backend != oldWidget.backend || session != oldWidget.session;
}
