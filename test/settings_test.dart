import 'package:flutter/material.dart';
import 'package:flutter_starter/core/storage/key_value_storage.dart';
import 'package:flutter_starter/features/settings/data/settings_repository.dart';
import 'package:flutter_starter/features/settings/presentation/settings_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'settings persist, restore, reset and invalid values fall back',
    () async {
      final storage = MemoryKeyValueStorage();
      final repository = PersistentSettingsRepository(storage);
      await repository.save(
        const SettingsValue(themeMode: ThemeMode.dark, locale: Locale('ru')),
      );
      var loaded = await PersistentSettingsRepository(storage).load();
      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.locale.languageCode, 'ru');
      await storage.setString('settings.theme', 'invalid');
      await storage.setString('settings.locale', 'xx');
      loaded = await repository.load();
      expect(loaded.themeMode, ThemeMode.system);
      expect(loaded.locale.languageCode, 'en');
      await repository.reset();
      expect((await repository.load()).themeMode, ThemeMode.system);
    },
  );
  test('bloc loads and changes values', () async {
    final bloc = SettingsBloc(
      PersistentSettingsRepository(MemoryKeyValueStorage()),
    );
    bloc.add(const SettingsLoaded());
    await expectLater(
      bloc.stream,
      emits(predicate<SettingsState>((s) => s.ready)),
    );
    bloc.add(const ThemeChanged(ThemeMode.dark));
    await expectLater(
      bloc.stream,
      emits(predicate<SettingsState>((s) => s.themeMode == ThemeMode.dark)),
    );
    bloc.add(const LocaleChanged(Locale('ru')));
    await expectLater(
      bloc.stream,
      emits(predicate<SettingsState>((s) => s.locale.languageCode == 'ru')),
    );
    bloc.add(const SettingsReset());
    await expectLater(
      bloc.stream,
      emits(
        predicate<SettingsState>(
          (s) =>
              s.themeMode == ThemeMode.system && s.locale.languageCode == 'en',
        ),
      ),
    );
    await bloc.close();
  });
}
