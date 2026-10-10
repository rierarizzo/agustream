import 'package:agustream/app/theme/app_theme.dart';
import 'package:agustream/ui/player/player_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onPlayPause,
    bool playing = true,
    VoidCallback? onBack,
    VoidCallback? onToggleFullscreen,
    ValueChanged<Duration>? onSeek,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: PlayerControls(
            title: 'Arrival',
            playing: playing,
            position: const Duration(minutes: 1),
            duration: const Duration(minutes: 2),
            volume: 100,
            visible: true,
            onPlayPause: onPlayPause,
            onSeek: onSeek ?? (_) {},
            onSeekBy: (_) {},
            onVolumeChanged: (_) {},
            onToggleFullscreen: onToggleFullscreen ?? () {},
            onSubtitles: () {},
            onAudio: () {},
            onBack: onBack ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows the title, the time and the play/pause state', (
    tester,
  ) async {
    await pump(tester, onPlayPause: () {});

    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('01:00 / 02:00'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('calls the play/pause callback', (tester) async {
    var taps = 0;
    await pump(tester, onPlayPause: () => taps++);

    await tester.tap(find.byTooltip('Pause'));

    expect(taps, 1);
  });

  testWidgets('calls back and fullscreen callbacks', (tester) async {
    var back = 0;
    var fullscreen = 0;
    await pump(
      tester,
      onPlayPause: () {},
      onBack: () => back++,
      onToggleFullscreen: () => fullscreen++,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.tap(find.byTooltip('Fullscreen'));

    expect(back, 1);
    expect(fullscreen, 1);
  });

  testWidgets('seeks when the bar changes', (tester) async {
    Duration? sought;
    await pump(tester, onPlayPause: () {}, onSeek: (value) => sought = value);

    await tester.drag(find.byType(Slider).first, const Offset(120, 0));

    expect(sought, isNotNull);
    expect(sought!, greaterThan(const Duration(minutes: 1)));
  });
}
