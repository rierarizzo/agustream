import 'package:http/http.dart' as http;

import '../../domain/addons/stream_repository.dart';
import '../../domain/backend/addon.dart';
import '../../domain/backend/addon_repository.dart';
import 'stremio_addon_client.dart';

/// [StreamRepository] backed by Stremio addons.
///
/// Unlike metadata, streams are **aggregated**: every enabled addon is asked,
/// in parallel, and the results are grouped by addon. An addon that fails or
/// has no streams for the title is skipped.
class StremioStreamRepository implements StreamRepository {
  StremioStreamRepository({
    required this.addons,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  /// Installed addons, asked in their order.
  final AddonRepository addons;

  final http.Client Function() _clientFactory;
  final Map<String, StremioAddonClient> _clients = {};

  @override
  Future<List<StreamGroup>> all({
    required String type,
    required String id,
  }) async {
    final List<Addon> installed;
    try {
      installed = await addons.all();
    } on Exception {
      // Without addons there is nothing to ask.
      return const [];
    }

    final groups = await Future.wait(
      installed.map((addon) => _streamsFor(addon, type, id)),
    );
    return groups.whereType<StreamGroup>().toList(growable: false);
  }

  Future<StreamGroup?> _streamsFor(
    Addon addon,
    String type,
    String id,
  ) async {
    final baseUrl = normalizeAddonBaseUrl(addon.url);
    if (baseUrl.isEmpty) return null;
    try {
      final streams = await _clientFor(baseUrl).fetchStreams(type: type, id: id);
      if (streams.isEmpty) return null;
      return StreamGroup(
        addonName: addon.name ?? Uri.parse(baseUrl).host,
        streams: streams,
      );
    } on Exception {
      // A streams-less or unreachable addon is skipped.
      return null;
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
