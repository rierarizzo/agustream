import 'package:agustream/app/theme/app_theme.dart';
import 'package:agustream/domain/addons/stream.dart';
import 'package:agustream/domain/addons/stream_repository.dart';
import 'package:agustream/ui/streams/streams_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required FakeStreamRepository streams,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: StreamsDialog(
            streams: streams,
            type: 'movie',
            id: 'tt1',
            title: 'Resident Evil',
            year: '2002',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the addon format as-is (name + description)', (
    tester,
  ) async {
    final streams = FakeStreamRepository(
      groups: const [
        StreamGroup(
          addonName: 'AIOStreams',
          streams: [
            Stream(
              url: 'https://a/1',
              name: '✨ 4K 🎫\nBLURAY REMUX',
              description: '🔆 DV • HDR10  🔊 Atmos\n📦 62.8 GB',
            ),
          ],
        ),
      ],
    );

    await pumpDialog(tester, streams: streams);

    expect(find.textContaining('4K'), findsOneWidget);
    expect(find.textContaining('BLURAY REMUX'), findsOneWidget);
    expect(find.textContaining('DV • HDR10'), findsOneWidget);
    expect(find.text('Resident Evil'), findsOneWidget);
    expect(find.text('2002'), findsOneWidget);
    expect(find.text('1 version'), findsOneWidget);
  });

  testWidgets('filters the list by the query', (tester) async {
    final streams = FakeStreamRepository(
      groups: const [
        StreamGroup(
          addonName: 'AIOStreams',
          streams: [
            Stream(url: 'https://a/1', name: '1080p', description: 'WEB-DL'),
            Stream(url: 'https://a/2', name: '4K', description: 'REMUX'),
          ],
        ),
      ],
    );

    await pumpDialog(tester, streams: streams);
    expect(find.text('2 versions'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'remux');
    await tester.pumpAndSettle();

    expect(find.text('REMUX'), findsOneWidget);
    expect(find.text('WEB-DL'), findsNothing);
  });

  testWidgets('shows an empty message when there are no streams', (
    tester,
  ) async {
    await pumpDialog(tester, streams: FakeStreamRepository());

    expect(find.text('No sources found for this title.'), findsOneWidget);
  });

  testWidgets('reports a failed load', (tester) async {
    await pumpDialog(
      tester,
      streams: FakeStreamRepository(failure: Exception('backend down')),
    );

    expect(find.text('Could not load sources from your addons.'), findsOneWidget);
  });

  testWidgets('pops with the chosen stream', (tester) async {
    Stream? selected;
    final streams = FakeStreamRepository(
      groups: const [
        StreamGroup(
          addonName: 'AIOStreams',
          streams: [Stream(url: 'https://a/1', name: '1080p')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showDialog<Stream>(
                    context: context,
                    builder: (_) => StreamsDialog(
                      streams: streams,
                      type: 'movie',
                      id: 'tt1',
                      title: 'Resident Evil',
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(selected?.url, 'https://a/1');
  });
}
