import 'package:shared_preferences/shared_preferences.dart';

import 'disclosure_store.dart';

final class SharedPreferencesDisclosureStore implements DisclosureStore {
  SharedPreferencesDisclosureStore._(this._preferences);

  static const key = 'disclosure.camera_cloud.v1';

  final SharedPreferences _preferences;

  static Future<SharedPreferencesDisclosureStore> create() async {
    return SharedPreferencesDisclosureStore._(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  Future<bool> hasAccepted() async => _preferences.getBool(key) ?? false;

  @override
  Future<void> accept() async {
    await _preferences.setBool(key, true);
  }
}
