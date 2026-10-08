import 'package:agustream/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend_provider.dart';

void main() {
  testWidgets('shell shows the rail and switches sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(AgustreamApp(backend: FakeBackendProvider()));

    // The home section is selected by default.
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Library'));
    await tester.pumpAndSettle();

    // The library section replaces it, and home is offstage.
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Library'), findsNothing);
  });
}
