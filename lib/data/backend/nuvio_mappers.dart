// Translates Nuvio (PostgREST) rows into the domain models.
//
// The mapping lives here, in the backend implementation, so the domain models
// stay free of database column names and can be produced by any backend.

import '../../domain/backend/addon.dart';
import '../../domain/backend/backend_profile.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/watch_progress.dart';
import '../../domain/shared/json_utils.dart';

/// Builds a [BackendProfile] from a `profiles` row.
BackendProfile backendProfileFromRow(Map<String, dynamic> json) {
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

/// Builds a [LibraryItem] from a `library_items` row.
LibraryItem libraryItemFromRow(Map<String, dynamic> json) {
  return LibraryItem(
    id: json['id'] as String? ?? '',
    contentId: json['content_id'] as String? ?? '',
    contentType: json['content_type'] as String? ?? '',
    name: json['name'] as String? ?? '',
    poster: json['poster'] as String?,
    posterShape: json['poster_shape'] as String?,
    background: json['background'] as String?,
    logo: json['logo'] as String?,
    description: json['description'] as String?,
    releaseInfo: json['release_info'] as String?,
    imdbRating: toDouble(json['imdb_rating']),
    genres: stringList(json['genres']),
    addonBaseUrl: json['addon_base_url'] as String?,
    addedAt: toDateTimeMillis(json['added_at']),
    profileId: toInt(json['profile_id']),
  );
}

/// Builds a [WatchProgress] from a `watch_progress` row.
WatchProgress watchProgressFromRow(Map<String, dynamic> json) {
  return WatchProgress(
    id: json['id'] as String? ?? '',
    contentId: json['content_id'] as String? ?? '',
    contentType: json['content_type'] as String? ?? '',
    videoId: json['video_id'] as String?,
    season: toInt(json['season']),
    episode: toInt(json['episode']),
    position: toDurationMillis(json['position']),
    duration: toDurationMillis(json['duration']),
    lastWatched: toDateTimeMillis(json['last_watched']),
    progressKey: json['progress_key'] as String?,
    profileId: toInt(json['profile_id']),
  );
}

/// Builds an [Addon] from an `addons` row.
Addon addonFromRow(Map<String, dynamic> json) {
  return Addon(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    name: json['name'] as String?,
    enabled: toBool(json['enabled']) ?? true,
    sortOrder: toInt(json['sort_order']) ?? 0,
    profileId: toInt(json['profile_id']),
  );
}
