import 'package:agustream/domain/backend/watch_progress.dart';
import 'package:agustream/domain/player/playback_target.dart';
import 'package:agustream/services/player/playback_progress_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_repositories.dart';

void main() {
  PlaybackTarget movie() => PlaybackTarget.fromContent(
    type: 'movie',
    id: 'tt1',
    title: 'Arrival',
    source: 'https://x/1',
  );

  test('resumes from a saved position inside the window', () async {
    final progress = FakeProgressRepository(
      entries: [
        const WatchProgress(
          id: 'p',
          contentId: 'tt1',
          contentType: 'movie',
          position: Duration(minutes: 30),
          duration: Duration(minutes: 100),
          progressKey: 'tt1',
        ),
      ],
    );
    final reporter = PlaybackProgressReporter(
      repository: progress,
      target: movie(),
    );

    expect(await reporter.resumePosition(), const Duration(minutes: 30));
  });

  test('does not resume a finished title', () async {
    final progress = FakeProgressRepository(
      entries: [
        const WatchProgress(
          id: 'p',
          contentId: 'tt1',
          contentType: 'movie',
          position: Duration(minutes: 99),
          duration: Duration(minutes: 100),
          progressKey: 'tt1',
        ),
      ],
    );
    final reporter = PlaybackProgressReporter(
      repository: progress,
      target: movie(),
    );

    expect(await reporter.resumePosition(), isNull);
  });

  test('saves progress with the account identity', () async {
    final progress = FakeProgressRepository();
    final reporter = PlaybackProgressReporter(
      repository: progress,
      target: movie(),
    );

    reporter.update(
      position: const Duration(minutes: 12),
      duration: const Duration(minutes: 100),
    );
    await reporter.flush(force: true);

    final saved = progress.entries.single;
    expect(saved.contentId, 'tt1');
    expect(saved.progressKey, 'tt1');
    expect(saved.position, const Duration(minutes: 12));
    expect(saved.duration, const Duration(minutes: 100));
    expect(saved.lastWatched, isNotNull);
  });

  test('throttles writes while playing', () async {
    final progress = FakeProgressRepository();
    final reporter = PlaybackProgressReporter(
      repository: progress,
      target: movie(),
    );

    reporter.update(
      position: const Duration(seconds: 40),
      duration: const Duration(minutes: 100),
    );
    await reporter.flush();
    reporter.update(
      position: const Duration(seconds: 45),
      duration: const Duration(minutes: 100),
    );
    await reporter.flush();

    expect(progress.entries, hasLength(1));
  });

  test('ignores a target without an identity', () async {
    final progress = FakeProgressRepository();
    final reporter = PlaybackProgressReporter(
      repository: progress,
      target: PlaybackTarget.raw('/tmp/x.mkv'),
    );

    reporter.update(
      position: const Duration(minutes: 1),
      duration: const Duration(minutes: 2),
    );
    await reporter.flush(force: true);

    expect(progress.entries, isEmpty);
  });
}
