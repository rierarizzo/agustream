import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/theme/app_theme.dart';
import '../../app/window/window_controller.dart';

/// Height of the custom title bar, matching the Windows 11 caption.
const double kTitleBarHeight = 32;

/// Windows 11-style title bar drawn with Flutter widgets.
///
/// Replaces the native caption hidden by [WindowController]. The caption buttons
/// are the real Windows 11 ones shipped by `window_manager` (correct glyphs,
/// hover and pressed states).
///
/// The background is opaque on purpose: a transparent title bar is not repainted
/// when the window is resized, which leaves the previous caption glyphs behind
/// as "ghosting" artifacts.
///
/// Like the reference UI, the bar shows only the window controls; the rest is a
/// drag area (see [_TitleBarDragArea]).
class TitleBar extends StatefulWidget {
  const TitleBar({super.key});

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  /// The window is created windowed (see [WindowController.initialize]), so the
  /// initial state is "not maximized". It is kept in sync through
  /// [WindowListener] events rather than by querying the OS, which also keeps
  /// the widget testable without platform channels.
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.background,
      child: SizedBox(
        height: kTitleBarHeight,
        child: Row(
          children: [
            Expanded(
              child: _TitleBarDragArea(
                isMaximized: _isMaximized,
                child: const SizedBox.expand(),
              ),
            ),
            WindowCaptionButton.minimize(
              brightness: theme.brightness,
              onPressed: WindowController.minimize,
            ),
            if (_isMaximized)
              WindowCaptionButton.unmaximize(
                brightness: theme.brightness,
                onPressed: WindowController.unmaximize,
              )
            else
              WindowCaptionButton.maximize(
                brightness: theme.brightness,
                onPressed: WindowController.maximize,
              ),
            WindowCaptionButton.close(
              brightness: theme.brightness,
              onPressed: WindowController.close,
            ),
          ],
        ),
      ),
    );
  }
}

/// Draggable region of the [TitleBar].
///
/// `window_manager`'s own `DragToMoveArea` cannot move a maximized window: the
/// OS refuses to start a move loop while the window is maximized, so the drag
/// silently does nothing. This variant restores the window first, matching how
/// Windows 11 behaves when you drag a maximized caption.
class _TitleBarDragArea extends StatelessWidget {
  const _TitleBarDragArea({required this.isMaximized, required this.child});

  final bool isMaximized;
  final Widget child;

  Future<void> _startDragging() async {
    if (isMaximized) {
      await windowManager.unmaximize();
    }
    await windowManager.startDragging();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: child,
    );
  }
}
