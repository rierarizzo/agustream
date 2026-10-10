import 'package:http/http.dart' as http;

import '../../domain/addons/subtitle.dart';
import '../../domain/addons/subtitle_repository.dart';
import '../../domain/backend/addon.dart';
import '../../domain/backend/addon_repository.dart';
import 'stremio_addon_client.dart';

/// [SubtitleRepository] backed by Stremio addons.
///
/// Subtitles are aggregated from every enabled addon, in parallel, and deduped
/// by URL. An addon that fails or has no subtitles for the title is skipped.
class StremioSubtitleRepository implements SubtitleRepository {
  StremioSubtitleRepository({
    required this.addons,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  /// Installed addons, asked in their order.
  final AddonRepository addons;

  final http.Client Function() _clientFactory;
  final Map<String, StremioAddonClient> _clients = {};

  @override
  Future<List<Subtitle>> all({
    required String type,
    required String id,
  }) async {
    final List<Addon> installed;
    try {
      installed = await addons.all();
    } on Exception {
      return const [];
    }

    final lists = await Future.wait(
      installed.map((addon) => _subtitlesFor(addon, type, id)),
    );

    final seen = <String>{};
    final result = <Subtitle>[];
    for (final list in lists) {
      for (final subtitle in list) {
        if (subtitle.url.isEmpty || !seen.add(subtitle.url)) continue;
        result.add(subtitle);
      }
    }
    return result;
  }

  Future<List<Subtitle>> _subtitlesFor(
    Addon addon,
    String type,
    String id,
  ) async {
    final baseUrl = normalizeAddonBaseUrl(addon.url);
    if (baseUrl.isEmpty) return const [];
    try {
      final subtitles = await _clientFor(
        baseUrl,
      ).fetchSubtitles(type: type, id: id);
      final name = addon.name ?? Uri.parse(baseUrl).host;
      return [
        for (final subtitle in subtitles) subtitle.withAddon(name),
      ];
    } on Exception {
      // An addon without a subtitles resource is skipped.
      return const [];
    }
  }

  StremioAddonClient _clientFor(String baseUrl) => _clients.putIfAbsent(
    baseUrl,
    () => StremioAddonClient(baseUrl: baseUrl, httpClient: _clientFactory()),
  );

  /// Closes every cached client.
  void close() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }
}
