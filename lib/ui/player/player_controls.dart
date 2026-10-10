import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Overlay controls for the player: back, title, seek bar, play/pause, time,
/// volume and fullscreen.
///
/// Pure: it takes plain values and callbacks, so it can be rendered and tested
/// without a native player.
class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.title,
    required this.playing,
    required this.position,
    required this.duration,
    required this.volume,
    required this.visible,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSeekBy,
    required this.onVolumeChanged,
    required this.onToggleFullscreen,
    required this.onSubtitles,
    required this.onAudio,
    required this.onBack,
  });

  final String title;
  final bool playing;
  final Duration position;
  final Duration duration;

  /// `0`–`100`.
  final double volume;

  final bool visible;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSeekBy;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onSubtitles;
  final VoidCallback onAudio;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !visible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(alignment: Alignment.topCenter, child: _top()),
            if (!playing)
              Center(
                child: _circleButton(
                  icon: Icons.play_arrow,
                  size: 44,
                  tooltip: 'Play',
                  onPressed: onPlayPause,
                ),
              ),
            Align(alignment: Alignment.bottomCenter, child: _bottom(context)),
          ],
        ),
      ),
    );
  }

  Widget _top() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final maxValue = totalMs <= 0 ? 1.0 : totalMs.toDouble();
    final value = position.inMilliseconds.clamp(0, totalMs).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              max: maxValue,
              onChanged: totalMs <= 0
                  ? null
                  : (ms) => onSeek(Duration(milliseconds: ms.round())),
            ),
          ),
          Row(
            children: [
              _iconButton(
                icon: playing ? Icons.pause : Icons.play_arrow,
                tooltip: playing ? 'Pause' : 'Play',
                onPressed: onPlayPause,
              ),
              _iconButton(
                icon: Icons.replay_10,
                tooltip: 'Back 10 seconds',
                onPressed: () => onSeekBy(const Duration(seconds: -10)),
              ),
              _iconButton(
                icon: Icons.forward_10,
                tooltip: 'Forward 10 seconds',
                onPressed: () => onSeekBy(const Duration(seconds: 10)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${_format(position)} / ${_format(duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const Spacer(),
              const Icon(Icons.volume_up, color: Colors.white, size: 20),
              SizedBox(
                width: 110,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: volume.clamp(0, 100),
                    max: 100,
                    onChanged: onVolumeChanged,
                  ),
                ),
              ),
              _iconButton(
                icon: Icons.subtitles_outlined,
                tooltip: 'Subtitles',
                onPressed: onSubtitles,
              ),
              _iconButton(
                icon: Icons.audiotrack,
                tooltip: 'Audio',
                onPressed: onAudio,
              ),
              _iconButton(
                icon: Icons.fullscreen,
                tooltip: 'Fullscreen',
                onPressed: onToggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
    );
  }

  Widget _circleButton({
    required IconData icon,
    required double size,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size,
      color: Colors.white,
      style: IconButton.styleFrom(backgroundColor: Colors.black45),
      icon: Icon(icon),
    );
  }

  static String _format(Duration value) {
    final total = value.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}
