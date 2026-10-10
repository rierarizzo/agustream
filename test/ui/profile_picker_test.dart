import 'package:agustream/app/app.dart';
import 'package:agustream/domain/backend/backend_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

void main() {
  /// Pumps the app with the given fakes and opens the library section.
  Future<void> pumpApp(
    WidgetTester tester, {
    FakeAccountRepository? account,
    FakeLibraryRepository? library,
    FakeProgressRepository? progress,
    FakeMetadataRepository? metadata,
    FakeStreamRepository? streams,
  }) async {
    await tester.pumpWidget(
      AgustreamApp(
        account: account ?? FakeAccountRepository(),
        library: library ?? FakeLibraryRepository(),
        progress: progress ?? FakeProgressRepository(),
        metadata: metadata ?? FakeMetadataRepository(),
        streams: streams ?? FakeStreamRepository(),
        catalogs: FakeCatalogRepository(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('blocks the app until a profile is chosen', (tester) async {
    await pumpApp(tester, account: FakeAccountRepository(withProfile: false));

    expect(find.text('Who is watching?'), findsOneWidget);
    expect(find.text('Tester'), findsOneWidget);
    // The rail is not reachable while the choice is pending.
    expect(find.byTooltip('Library'), findsNothing);
    expect(find.byTooltip('Settings'), findsNothing);

    await tester.tap(find.text('Tester'));
    await tester.pumpAndSettle();

    expect(find.text('Who is watching?'), findsNothing);
    expect(find.byTooltip('Library'), findsOneWidget);
  });

  testWidgets('offers a retry when the profiles cannot be loaded', (
    tester,
  ) async {
    await pumpApp(
      tester,
      account: FakeAccountRepository(
        withProfile: false,
        profilesError: const BackendException('backend down'),
      ),
    );

    expect(find.text('Who is watching?'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('backend down'), findsOneWidget);
  });

  testWidgets('shows a spinner on the first load', (tester) async {
    // Not `pumpApp`: `pumpAndSettle` would wait forever on the spinner.
    await tester.pumpWidget(
      AgustreamApp(
        account: FakeAccountRepository(
          withProfile: false,
          isLoadingProfiles: true,
          availableProfiles: const [],
        ),
        library: FakeLibraryRepository(),
        progress: FakeProgressRepository(),
        metadata: FakeMetadataRepository(),
        streams: FakeStreamRepository(),
        catalogs: FakeCatalogRepository(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('This account has no profiles.'), findsNothing);
  });

  testWidgets('reports an account without profiles', (tester) async {
    await pumpApp(
      tester,
      account: FakeAccountRepository(
        withProfile: false,
        availableProfiles: const [],
      ),
    );

    expect(find.text('This account has no profiles.'), findsOneWidget);
  });

  testWidgets('does not block when there is no session', (tester) async {
    await pumpApp(
      tester,
      account: FakeAccountRepository(signedIn: false, withProfile: false),
    );

    expect(find.text('Who is watching?'), findsNothing);
    expect(find.byTooltip('Library'), findsOneWidget);
  });

  testWidgets('does not block when the backend has no profiles', (
    tester,
  ) async {
    await pumpApp(
      tester,
      account: FakeAccountRepository(
        requiresProfile: false,
        withProfile: false,
        availableProfiles: const [],
      ),
    );

    expect(find.text('Who is watching?'), findsNothing);
    expect(find.byTooltip('Library'), findsOneWidget);
  });
}
