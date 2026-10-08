import 'package:flutter/material.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/backend/account_repository.dart';
import '../../domain/backend/backend_profile.dart';

/// Asks which Nuvio profile to work with.
///
/// Shown as a gate: the library, the watch progress and every write belong to a
/// profile, so there is no safe default. Choosing one is mandatory.
class ProfilePicker extends StatelessWidget {
  const ProfilePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AppServices.of(context).account;
    return ListenableBuilder(
      listenable: account.changes,
      builder: (context, _) => _Body(account: account),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.account});

  final AccountRepository account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = account.profilesError;
    final isFirstLoad = account.isLoadingProfiles && account.profiles.isEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Who is watching?', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The library and the watch progress belong to a profile.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (isFirstLoad)
                const CircularProgressIndicator()
              else if (error != null)
                _Problem(
                  message: '$error',
                  onRetry: account.loadProfiles,
                )
              else if (account.profiles.isEmpty)
                _Problem(
                  message: 'This account has no profiles.',
                  onRetry: account.loadProfiles,
                )
              else
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final profile in account.profiles)
                      _ProfileTile(
                        profile: profile,
                        onTap: () => account.selectProfile(profile),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatefulWidget {
  const _ProfileTile({required this.profile, required this.onTap});

  final BackendProfile profile;
  final VoidCallback onTap;

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hovered ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: _Avatar(profile: profile),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(profile.name, style: theme.textTheme.bodyMedium),
              if (profile.pinEnabled)
                Text('PIN', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final BackendProfile profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;
    final color = _parseHex(profile.avatarColorHex) ?? AppColors.surfaceHigh;

    return ClipOval(
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color),
            if (avatarUrl != null && avatarUrl.startsWith('http'))
              Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _Initial(profile: profile),
              )
            else
              _Initial(profile: profile),
          ],
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.profile});

  final BackendProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.name.trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        initial,
        style: theme.textTheme.headlineMedium?.copyWith(fontSize: 34),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 36, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

/// Parses `#RRGGBB` / `RRGGBB`; `null` when the value is missing or malformed.
Color? _parseHex(String? value) {
  if (value == null) return null;
  final hex = value.replaceFirst('#', '').trim();
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}
