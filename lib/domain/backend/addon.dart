import '../shared/json_utils.dart';

/// One addon installed in the account (`addons`).
class Addon {
  const Addon({
    required this.id,
    required this.url,
    this.name,
    this.enabled = true,
    this.sortOrder = 0,
    this.profileId,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
    return Addon(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      name: json['name'] as String?,
      enabled: toBool(json['enabled']) ?? true,
      sortOrder: toInt(json['sort_order']) ?? 0,
      profileId: toInt(json['profile_id']),
    );
  }

  final String id;

  /// Manifest URL, e.g. `https://addon.example/manifest.json`.
  final String url;

  final String? name;
  final bool enabled;
  final int sortOrder;
  final int? profileId;
}
