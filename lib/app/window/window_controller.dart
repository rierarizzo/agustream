import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';

/// Owns the native OS window (an app-shell concern).
///
/// Hides the default Windows caption and applies the Windows 11 **Mica**
/// backdrop so the Flutter-drawn title bar blends with the app theme. Nothing
/// else in the app should talk to `window_manager` or `flutter_acrylic`
/// directly.
abstract final class WindowController {
  /// Size the window opens with.
  static const Size initialSize = Size(1280, 720);

  /// Smallest size the window can be resized to.
  static const Size minimumSize = Size(960, 600);

  /// Native window title (also shown by the custom title bar).
  static const String windowTitle = 'Agustream';

  /// Prepares the native window: hidden caption plus Mica backdrop.
  ///
  /// Must run before `runApp`.
  static Future<void> initialize() async {
    await Window.initialize();
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: initialSize,
      minimumSize: minimumSize,
      center: true,
      title: windowTitle,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await Window.setEffect(effect: WindowEffect.mica, dark: true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static Future<void> minimize() => windowManager.minimize();

  static Future<void> maximize() => windowManager.maximize();

  static Future<void> unmaximize() => windowManager.unmaximize();

  static Future<void> close() => windowManager.close();
}
