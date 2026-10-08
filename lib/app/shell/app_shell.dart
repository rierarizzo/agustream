import 'package:flutter/material.dart';

import '../../ui/widgets/title_bar.dart';
import '../window/window_controller.dart';

/// Persistent app chrome around the routed content.
///
/// Everything here is mounted through `MaterialApp.builder`, i.e. **above** the
/// `Navigator`, so it survives navigation. That is also why the fullscreen
/// decision lives here and in a single place: content routes are covered by the
/// video fullscreen route, but the chrome is not, so it has to hide itself.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  /// The routed content (the `Navigator`), provided by `MaterialApp.builder`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WindowController.isFullScreen,
      builder: (context, isFullScreen, _) {
        return Column(
          children: [
            if (!isFullScreen) const TitleBar(),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
