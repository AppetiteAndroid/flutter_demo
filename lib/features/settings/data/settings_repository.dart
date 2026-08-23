import 'package:flutter/material.dart';

import '../../../core/storage/key_value_storage.dart';

class SettingsValue {
  const SettingsValue({required this.themeMode, required this.locale});
  final ThemeMode themeMode;
  final Locale locale;
}

abstract interface class SettingsRepository {
  Future<SettingsValue> load();
  Future<void> save(SettingsValue value);
  Future<void> reset();
}

class PersistentSettingsRepository implements SettingsRepository {
  PersistentSettingsRepository(this.storage);
  final KeyValueStorage storage;
  static const _theme = 'settings.theme', _locale = 'settings.locale';
  Future<void> _writes = Future.value();
  @override
  Future<SettingsValue> load() async {
    final theme =
        ThemeMode.values
            .where((v) => v.name == storage.getString(_theme))
            .firstOrNull ??
        ThemeMode.system;
    final code = storage.getString(_locale);
    return SettingsValue(
      themeMode: theme,
      locale: Locale(code == 'ru' ? 'ru' : 'en'),
    );
  }

  @override
  Future<void> save(SettingsValue value) {
    return _writes = _writes.then((_) async {
      await storage.setString(_theme, value.themeMode.name);
      await storage.setString(_locale, value.locale.languageCode);
    });
  }

  @override
  Future<void> reset() async {
    await storage.remove(_theme);
    await storage.remove(_locale);
  }
}
