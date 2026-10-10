import 'package:agustream/app/app.dart';
import 'package:agustream/app/shell/app_chrome.dart';
import 'package:agustream/ui/home/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';

void main() {
  testWidgets('shell shows the rail and switches sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AgustreamApp(
        account: FakeAccountRepository(),
        library: FakeLibraryRepository(),
        progress: FakeProgressRepository(),
        metadata: FakeMetadataRepository(),
        streams: FakeStreamRepository(),
        catalogs: FakeCatalogRepository(),
      ),
    );

    // The home section is selected by default.
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Library'));
    await tester.pumpAndSettle();

    // The library section replaces it, and home is offstage.
    expect(find.text('Library'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Library'), findsNothing);
  });

  testWidgets('hides the rail while immersive', (tester) async {
    await tester.pumpWidget(
      AgustreamApp(
        account: FakeAccountRepository(),
        library: FakeLibraryRepository(),
        progress: FakeProgressRepository(),
        metadata: FakeMetadataRepository(),
        streams: FakeStreamRepository(),
        catalogs: FakeCatalogRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Library'), findsOneWidget);

    AppChrome.enterImmersive();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Library'), findsNothing);

    AppChrome.exitImmersive();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Library'), findsOneWidget);
  });
}
