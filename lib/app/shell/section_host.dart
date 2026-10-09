import 'package:flutter/material.dart';

import '../../ui/home/home_screen.dart';
import '../../ui/screens/library_screen.dart';
import '../../ui/screens/section_placeholder.dart';
import '../../ui/screens/settings_screen.dart';
import 'app_section.dart';

/// Content of the shell: shows [selected].
///
/// Sections are kept alive in an [IndexedStack] (so scroll position and loaded
/// data survive switching) but are only built once visited, so an unopened
/// section never fires its own requests at startup.
class SectionHost extends StatefulWidget {
  const SectionHost({super.key, required this.selected});

  final AppSection selected;

  @override
  State<SectionHost> createState() => _SectionHostState();
}

class _SectionHostState extends State<SectionHost> {
  final Set<AppSection> _visited = <AppSection>{AppSection.home};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.selected);
  }

  @override
  void didUpdateWidget(covariant SectionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.selected.index,
      children: [
        for (final section in AppSection.values)
          _visited.contains(section)
              ? _screenFor(section)
              : const SizedBox.shrink(),
      ],
    );
  }

  Widget _screenFor(AppSection section) {
    return switch (section) {
      AppSection.home => const HomeScreen(),
      AppSection.library => const LibraryScreen(),
      AppSection.settings => const SettingsScreen(),
      _ => SectionPlaceholder(section: section),
    };
  }
}
