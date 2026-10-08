import 'json_utils.dart';

/// One playable stream returned by a `stream` resource.
class Stream {
  const Stream({
    this.url,
    this.ytId,
    this.infoHash,
    this.fileIdx,
    this.externalUrl,
    this.name,
    this.title,
    this.behaviorHints,
  });

  factory Stream.fromJson(Map<String, dynamic> json) {
    final hints = toJsonObject(json['behaviorHints']);
    return Stream(
      url: json['url'] as String?,
      ytId: json['ytId'] as String?,
      infoHash: json['infoHash'] as String?,
      fileIdx: toInt(json['fileIdx']),
      externalUrl: json['externalUrl'] as String?,
      name: json['name'] as String?,
      title: json['title'] as String?,
      behaviorHints: hints == null ? null : StreamBehaviorHints.fromJson(hints),
    );
  }

  /// Direct URL to play. Null for torrent/external-only streams.
  final String? url;

  final String? ytId;
  final String? infoHash;
  final int? fileIdx;

  /// URL to open outside the app (e.g. a web player).
  final String? externalUrl;

  /// Short label shown as the stream source, e.g. the addon or provider name.
  final String? name;

  /// Longer label, usually the file name or quality.
  final String? title;

  final StreamBehaviorHints? behaviorHints;

  /// Whether this stream can be handed straight to the player.
  bool get isDirectPlayable => url != null && url!.isNotEmpty;
}

/// The `behaviorHints` object of a [Stream].
class StreamBehaviorHints {
  const StreamBehaviorHints({
    this.bingeGroup,
    this.filename,
    this.videoSize,
    this.proxyHeaders,
  });

  factory StreamBehaviorHints.fromJson(Map<String, dynamic> json) {
    return StreamBehaviorHints(
      bingeGroup: json['bingeGroup'] as String?,
      filename: json['filename'] as String?,
      videoSize: toInt(json['videoSize']),
      proxyHeaders: toJsonObject(json['proxyHeaders']),
    );
  }

  /// Groups streams that belong to the same release, for binge-watching.
  final String? bingeGroup;

  final String? filename;

  /// Size in bytes.
  final int? videoSize;

  /// Headers the player must send when requesting [Stream.url].
  final Map<String, dynamic>? proxyHeaders;
}
