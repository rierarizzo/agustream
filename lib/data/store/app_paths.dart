import 'dart:io';

/// `%APPDATA%\Agustream` on Windows, XDG config elsewhere. Not created here.
String agustreamConfigDir() {
  final env = Platform.environment;
  final separator = Platform.pathSeparator;
  final base = Platform.isWindows
      ? (env['APPDATA'] ?? env['LOCALAPPDATA'] ?? '.')
      : (env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '.'}/.config');
  return '$base${separator}Agustream';
}

/// File the persisted session lives in.
String sessionFilePath() =>
    '${agustreamConfigDir()}${Platform.pathSeparator}session.json';

/// Directory the local backend (`BackendKind.local`) stores its data in.
String localStoreDir() =>
    '${agustreamConfigDir()}${Platform.pathSeparator}local';

/// File the per-series "fully watched" cache lives in.
String watchedSeriesCachePath() =>
    '${agustreamConfigDir()}${Platform.pathSeparator}watched_series.json';
