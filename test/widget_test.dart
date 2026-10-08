import 'package:flutter_test/flutter_test.dart';

import 'package:agustream/app/app.dart';

void main() {
  testWidgets('app boots and shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AgustreamApp());

    expect(find.text('Agustream'), findsOneWidget);
    expect(find.text('Agustream scaffold is running.'), findsOneWidget);
  });
}
