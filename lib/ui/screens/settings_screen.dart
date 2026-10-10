import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/backend/account_repository.dart';
import '../../domain/backend/backend_exception.dart';
import '../../domain/player/playback_target.dart';
import 'player_screen.dart';

/// Settings section.
///
/// For now it holds two temporary cards: one to sign in (the library needs a
/// session and the real login screen is not built yet) and the phase 1 playback
/// test. The real settings (playback, subtitles, account, ...) come in a later
/// part.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _open(String source) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(target: PlaybackTarget.raw(source)),
      ),
    );
  }

  Future<void> _playUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _open(url);
  }

  Future<void> _openFile() async {
    const typeGroup = XTypeGroup(
      label: 'Video',
      extensions: <String>['mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;
    await _open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = AppServices.of(context).account;

    return ListenableBuilder(
      listenable: account.changes,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Settings', style: theme.textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.lg),
          _AccountCard(account: account),
          const SizedBox(height: AppSpacing.lg),
          _Card(
            title: 'Open a video (temporary)',
            subtitle:
                'Playback test kept from phase 1. Removed once the player is '
                'integrated.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Video URL',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _playUrl(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _playUrl,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play URL'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _openFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Open local file'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Signs in and out of the account backend.
///
/// Temporary: it exists so the library can be tested with a real account before
/// the login screen is designed.
class _AccountCard extends StatefulWidget {
  const _AccountCard({required this.account});

  final AccountRepository account;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.account.signIn(email: email, password: password);
      _password.clear();
    } on BackendException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await widget.account.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = widget.account;

    if (account.isSignedIn) {
      return _Card(
        title: 'Account',
        subtitle: 'Signed in as ${account.email ?? 'your account'}.',
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ),
      );
    }

    return _Card(
      title: 'Account',
      subtitle:
          'Sign in to load your library. Temporary: the real login '
          'screen arrives with the settings part.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _password,
            obscureText: true,
            onSubmitted: (_) => _signIn(),
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
