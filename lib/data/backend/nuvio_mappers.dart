// Translates Nuvio (PostgREST) rows into the domain models.
//
// The mapping lives here, in the backend implementation, so the domain models
// stay free of database column names and can be produced by any backend.

import '../../domain/backend/addon.dart';
import '../../domain/backend/backend_profile.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/watch_progress.dart';
import '../../domain/backend/watched_entry.dart';
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

/// Serializes a [LibraryItem] into the writable columns of `library_items`.
///
/// `id` is left out: the backend assigns it. `(profile_id, user_id)` scope the
/// row and are required by row-level security, so [userId] must be the signed-in
/// auth user. `added_at` is always sent because the column defaults to `0`, not
/// to now. [userId] and [profileId] are omitted when null (the local store has
/// neither).
Map<String, dynamic> libraryItemToRow(
  LibraryItem item, {
  int? profileId,
  String? userId,
}) {
  return {
    'user_id': ?userId,
    'content_id': item.contentId,
    'content_type': item.contentType,
    'name': item.name,
    if (item.poster != null) 'poster': item.poster,
    if (item.posterShape != null) 'poster_shape': item.posterShape,
    if (item.background != null) 'background': item.background,
    if (item.logo != null) 'logo': item.logo,
    if (item.description != null) 'description': item.description,
    if (item.releaseInfo != null) 'release_info': item.releaseInfo,
    if (item.imdbRating != null) 'imdb_rating': item.imdbRating,
    if (item.genres.isNotEmpty) 'genres': item.genres,
    if (item.addonBaseUrl != null) 'addon_base_url': item.addonBaseUrl,
    'added_at': (item.addedAt ?? DateTime.now().toUtc())
        .millisecondsSinceEpoch,
    'profile_id': ?profileId,
  };
}

/// Serializes a [WatchProgress] into the writable columns of `watch_progress`.
///
/// Times are sent in milliseconds, like the reads. `last_watched` defaults to
/// now when the entry does not carry one. `user_id` scopes the row for
/// row-level security.
Map<String, dynamic> watchProgressToRow(
  WatchProgress progress, {
  int? profileId,
  String? userId,
}) {
  return {
    'user_id': ?userId,
    'content_id': progress.contentId,
    'content_type': progress.contentType,
    if (progress.videoId != null) 'video_id': progress.videoId,
    if (progress.season != null) 'season': progress.season,
    if (progress.episode != null) 'episode': progress.episode,
    if (progress.position != null)
      'position': progress.position!.inMilliseconds,
    if (progress.duration != null)
      'duration': progress.duration!.inMilliseconds,
    'last_watched': (progress.lastWatched ?? DateTime.now().toUtc())
        .millisecondsSinceEpoch,
    if (progress.progressKey != null) 'progress_key': progress.progressKey,
    'profile_id': ?profileId,
  };
}

/// Builds a [WatchedEntry] from a `watched_items` row.
WatchedEntry watchedEntryFromRow(Map<String, dynamic> json) {
  return WatchedEntry(
    contentId: json['content_id'] as String? ?? '',
    contentType: json['content_type'] as String? ?? '',
    season: toInt(json['season']),
    episode: toInt(json['episode']),
  );
}
