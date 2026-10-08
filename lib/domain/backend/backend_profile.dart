import '../shared/json_utils.dart';

/// A Nuvio profile (one account can have several).
class BackendProfile {
  const BackendProfile({
    required this.id,
    required this.name,
    this.profileId,
    this.profileIndex,
    this.avatarId,
    this.avatarUrl,
    this.avatarColorHex,
    this.pinEnabled = false,
  });

  factory BackendProfile.fromJson(Map<String, dynamic> json) {
    return BackendProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profileId: toInt(json['profile_id']),
      profileIndex: toInt(json['profile_index']),
      avatarId: json['avatar_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarColorHex: json['avatar_color_hex'] as String?,
      pinEnabled: toBool(json['pin_enabled']) ?? false,
    );
  }

  /// Primary key (uuid).
  final String id;

  final String name;

  /// Integer id that `library_items` and `watch_progress` reference.
  final int? profileId;

  final int? profileIndex;
  final String? avatarId;
  final String? avatarUrl;
  final String? avatarColorHex;
  final bool pinEnabled;
}
