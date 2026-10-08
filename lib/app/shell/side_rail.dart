import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_section.dart';

/// Icon-only navigation rail, fixed to the left edge of the shell.
///
/// Sections live in the content area, not here: the rail only reports which
/// one is selected.
class SideRail extends StatelessWidget {
  const SideRail({
    super.key,
    required this.selected,
    required this.onSelected,
    this.avatar,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;

  /// Profile avatar shown at the top. A placeholder is used when null.
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SizedBox(
        width: AppSizes.sideRailWidth,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            avatar ?? const _AvatarPlaceholder(),
            const SizedBox(height: AppSpacing.md),
            for (final section in AppSection.values)
              if (section != AppSection.settings)
                _RailButton(
                  section: section,
                  selected: section == selected,
                  onTap: () => onSelected(section),
                ),
            const Spacer(),
            _RailButton(
              section: AppSection.settings,
              selected: selected == AppSection.settings,
              onTap: () => onSelected(AppSection.settings),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Tooltip(
        message: section.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            width: AppSizes.railButton,
            height: AppSizes.railButton,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? AppColors.surfaceHigh : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(
                selected ? section.selectedIcon : section.icon,
                size: 20,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stand-in for the profile avatar until the backend profile is wired up.
class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.surfaceHigh,
      child: Icon(Icons.person, size: 18, color: AppColors.textSecondary),
    );
  }
}
