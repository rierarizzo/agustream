import 'package:agustream/app/shell/app_chrome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('immersive is counted and balanced', () {
    expect(AppChrome.immersive.value, isFalse);

    AppChrome.enterImmersive();
    AppChrome.enterImmersive();
    expect(AppChrome.immersive.value, isTrue);

    AppChrome.exitImmersive();
    expect(AppChrome.immersive.value, isTrue);

    AppChrome.exitImmersive();
    expect(AppChrome.immersive.value, isFalse);

    // An extra release (e.g. a route disposed twice) is ignored.
    AppChrome.exitImmersive();
    expect(AppChrome.immersive.value, isFalse);
  });
}
