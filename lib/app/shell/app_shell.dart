import 'package:flutter/material.dart';

import '../../ui/widgets/title_bar.dart';
import '../theme/app_theme.dart';
import '../window/window_controller.dart';
import 'app_section.dart';
import 'section_host.dart';
import 'side_rail.dart';

/// Persistent app chrome: navigation rail, title bar and the content area.
///
/// It is the app's root route, and the content area hosts its own [Navigator].
/// That gives three things:
///
/// * pushed screens (a title detail, for example) render **inside** the content
///   area, so the chrome stays visible;
/// * the chrome itself sits under an [Overlay], so tooltips and menus work;
/// * dialogs still cover the whole window, because `showDialog` uses the root
///   navigator by default.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ValueNotifier<AppSection> _selected = ValueNotifier(AppSection.home);
  final GlobalKey<NavigatorState> _contentNavigator =
      GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  void _select(AppSection section) {
    if (section == _selected.value) return;
    _selected.value = section;
    // Switching sections returns to that section's root.
    _contentNavigator.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WindowController.isFullScreen,
      builder: (context, isFullScreen, _) {
        return Row(
          children: [
            if (!isFullScreen)
              ValueListenableBuilder<AppSection>(
                valueListenable: _selected,
                builder: (context, section, _) =>
                    SideRail(selected: section, onSelected: _select),
              ),
            Expanded(
              child: Column(
                children: [
                  if (!isFullScreen) const TitleBar(),
                  Expanded(
                    // A Scaffold gives sections their Material ancestor (ink,
                    // text style, background), hosts SnackBars, and is the base
                    // for pushed routes too.
                    child: Scaffold(
                      backgroundColor: AppColors.background,
                      body: Navigator(
                        key: _contentNavigator,
                        onGenerateRoute: _onGenerateRoute,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Route<void> _onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ValueListenableBuilder<AppSection>(
        valueListenable: _selected,
        builder: (context, section, _) => SectionHost(selected: section),
      ),
    );
  }
}
