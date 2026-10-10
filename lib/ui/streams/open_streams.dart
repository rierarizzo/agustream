import 'package:flutter/material.dart';

import '../../domain/addons/stream.dart';
import '../../domain/addons/stream_repository.dart';
import '../../domain/player/playback_target.dart';
import '../screens/player_screen.dart';
import 'streams_dialog.dart';

/// Opens the stream picker and plays the chosen source.
Future<void> openStreamsDialog(
  BuildContext context, {
  required StreamRepository streams,
  required String type,
  required String id,
  required String title,
  String? year,
  String? background,
}) async {
  final selected = await showDialog<Stream>(
    context: context,
    useRootNavigator: false,
    barrierColor: Colors.black54,
    builder: (_) => StreamsDialog(
      streams: streams,
      type: type,
      id: id,
      title: title,
      year: year,
      background: background,
    ),
  );
  if (!context.mounted || selected == null) return;
  playStream(context, type: type, id: id, title: title, stream: selected);
}

/// Plays [stream] with the integrated player, or explains why it cannot.
void playStream(
  BuildContext context, {
  required String type,
  required String id,
  required String title,
  required Stream stream,
}) {
  final url = stream.url;
  if (url == null || url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This source cannot be played yet (torrent or external link).',
        ),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(
        target: PlaybackTarget.fromContent(
          type: type,
          id: id,
          title: title,
          source: url,
          httpHeaders: stream.httpHeaders,
        ),
      ),
    ),
  );
}
