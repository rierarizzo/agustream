import 'dart:io';

import '../../data/backend/nuvio_account_repository.dart';
import '../../data/backend/nuvio_addon_repository.dart';
import '../../data/backend/nuvio_client.dart';
import '../../data/backend/nuvio_library_repository.dart';
import '../../data/backend/nuvio_progress_repository.dart';
import '../../data/local/local_account_repository.dart';
import '../../data/local/local_addon_repository.dart';
import '../../data/local/local_library_repository.dart';
import '../../data/local/local_progress_repository.dart';
import '../../data/store/app_paths.dart';
import '../../data/store/json_file_store.dart';
import '../../data/store/session_store.dart';
import '../../domain/backend/account_repository.dart';
import '../../domain/backend/addon.dart';
import '../../domain/backend/addon_repository.dart';
import '../../domain/backend/library_repository.dart';
import '../../domain/backend/progress_repository.dart';

/// Which backend provides the account, the library and the progress.
///
/// Adding a backend means adding a value here and a branch in [createBackend].
/// Nothing in `ui/` or `domain/` changes, because they only know the interfaces.
enum BackendKind {
  /// Nuvio's hosted (or self-hosted) Supabase backend.
  nuvio,

  /// Everything on this machine: no account, no profiles.
  local;

  /// Reads `AGUSTREAM_BACKEND`, defaulting to [nuvio] for an unknown value.
  static BackendKind fromEnvironment([Map<String, String>? environment]) {
    final raw = (environment ?? Platform.environment)['AGUSTREAM_BACKEND'];
    if (raw == null) return BackendKind.nuvio;
    final normalized = raw.trim().toLowerCase();
    for (final kind in BackendKind.values) {
      if (kind.name == normalized) return kind;
    }
    return BackendKind.nuvio;
  }
}

/// The repositories a backend provides, plus a way to release its resources.
class BackendBundle {
  const BackendBundle({
    required this.account,
    required this.library,
    required this.progress,
    required this.addons,
    this.close,
  });

  final AccountRepository account;
  final LibraryRepository library;
  final ProgressRepository progress;

  /// Addons installed in the account, consumed by the Stremio addon layer.
  final AddonRepository addons;

  /// Releases the backend resources (HTTP clients). Optional.
  final void Function()? close;
}

/// Builds the repositories for [kind].
///
/// It is the only place that knows the concrete implementations, so swapping
/// the backend is a change here and nowhere else.
BackendBundle createBackend({
  BackendKind kind = BackendKind.nuvio,
  String? baseUrl,
  SessionStore sessionStore = const NoopSessionStore(),
  String? localDir,
  List<Addon>? localAddons,
}) {
  switch (kind) {
    case BackendKind.nuvio:
      final client = NuvioClient(
        baseUrl: baseUrl ?? NuvioClient.defaultBaseUrl,
        sessionStore: sessionStore,
      );
      final account = NuvioAccountRepository(client);
      return BackendBundle(
        account: account,
        library: NuvioLibraryRepository(client, account),
        progress: NuvioProgressRepository(client, account),
        addons: NuvioAddonRepository(client, account),
        close: client.close,
      );
    case BackendKind.local:
      final dir = localDir ?? localStoreDir();
      return BackendBundle(
        account: LocalAccountRepository(),
        library: LocalLibraryRepository(JsonFileStore('$dir/library.json')),
        progress: LocalProgressRepository(
          JsonFileStore('$dir/progress.json'),
          watched: JsonFileStore('$dir/watched.json'),
        ),
        addons: LocalAddonRepository(
          localAddons ?? _localAddonsFromEnvironment(),
        ),
      );
  }
}

/// Addons for local mode from `AGUSTREAM_LOCAL_ADDONS`, comma-separated
/// manifest URLs. There is no addon management UI yet, so this is the only way
/// to give local mode catalogs.
List<Addon> _localAddonsFromEnvironment() {
  final raw = Platform.environment['AGUSTREAM_LOCAL_ADDONS'];
  if (raw == null) return const [];
  return [
    for (final url in raw.split(','))
      if (url.trim().isNotEmpty) _addonFor(url.trim()),
  ];
}

Addon _addonFor(String url) {
  final host = Uri.tryParse(url)?.host;
  return Addon(id: url, url: url, name: host == null || host.isEmpty ? url : host);
}
