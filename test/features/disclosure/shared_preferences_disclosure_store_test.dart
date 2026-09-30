import 'package:altinus_ocr/features/disclosure/shared_preferences_disclosure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('missing disclosure value is not accepted', () async {
    final store = await SharedPreferencesDisclosureStore.create();

    expect(await store.hasAccepted(), isFalse);
  });

  test(
    'accept persists the camera cloud disclosure under its versioned key',
    () async {
      final store = await SharedPreferencesDisclosureStore.create();

      await store.accept();

      expect(await store.hasAccepted(), isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('disclosure.camera_cloud.v1'), isTrue);
    },
  );
}
