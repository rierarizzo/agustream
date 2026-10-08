import 'package:flutter/material.dart';

/// The sections reachable from the navigation rail.
///
/// The order here is the order shown in the rail (settings is pinned to the
/// bottom by [SideRail]).
enum AppSection {
  home('Home', Icons.home_outlined, Icons.home),
  discover('Discover', Icons.explore_outlined, Icons.explore),
  search('Search', Icons.search, Icons.search),
  library('Library', Icons.favorite_border, Icons.favorite),
  calendar('Calendar', Icons.calendar_today_outlined, Icons.calendar_today),
  history('History', Icons.history, Icons.history),
  settings('Settings', Icons.settings_outlined, Icons.settings);

  const AppSection(this.label, this.icon, this.selectedIcon);

  /// Human-readable name, also used as the rail tooltip.
  final String label;

  final IconData icon;
  final IconData selectedIcon;
}
