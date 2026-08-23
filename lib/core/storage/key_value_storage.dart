import 'package:shared_preferences/shared_preferences.dart';

abstract interface class KeyValueStorage {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class SharedPreferencesStorage implements KeyValueStorage {
  SharedPreferencesStorage(this.preferences);
  final SharedPreferences preferences;
  @override
  String? getString(String key) => preferences.getString(key);
  @override
  Future<void> setString(String key, String value) =>
      preferences.setString(key, value);
  @override
  Future<void> remove(String key) => preferences.remove(key);
}

class MemoryKeyValueStorage implements KeyValueStorage {
  final Map<String, String> values = {};
  @override
  String? getString(String key) => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
