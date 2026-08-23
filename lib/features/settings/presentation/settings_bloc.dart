import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/settings_repository.dart';

sealed class SettingsEvent {
  const SettingsEvent();
}

class SettingsLoaded extends SettingsEvent {
  const SettingsLoaded();
}

class ThemeChanged extends SettingsEvent {
  const ThemeChanged(this.mode);
  final ThemeMode mode;
}

class LocaleChanged extends SettingsEvent {
  const LocaleChanged(this.locale);
  final Locale locale;
}

class SettingsReset extends SettingsEvent {
  const SettingsReset();
}

class SettingsState {
  const SettingsState({
    this.ready = false,
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
  });
  final bool ready;
  final ThemeMode themeMode;
  final Locale locale;
  SettingsState copyWith({bool? ready, ThemeMode? themeMode, Locale? locale}) =>
      SettingsState(
        ready: ready ?? this.ready,
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
      );
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this.repository, {SettingsValue? initial})
    : super(
        initial == null
            ? const SettingsState()
            : SettingsState(
                ready: true,
                themeMode: initial.themeMode,
                locale: initial.locale,
              ),
      ) {
    on<SettingsLoaded>(_load);
    on<ThemeChanged>(_theme);
    on<LocaleChanged>(_locale);
    on<SettingsReset>(_reset);
  }
  final SettingsRepository repository;
  Future<void> _load(SettingsLoaded event, Emitter<SettingsState> emit) async {
    try {
      final value = await repository.load();
      emit(
        SettingsState(
          ready: true,
          themeMode: value.themeMode,
          locale: value.locale,
        ),
      );
    } catch (_) {
      emit(const SettingsState(ready: true));
    }
  }

  Future<void> _theme(ThemeChanged event, Emitter<SettingsState> emit) async {
    final next = state.copyWith(themeMode: event.mode);
    emit(next);
    await repository.save(
      SettingsValue(themeMode: next.themeMode, locale: next.locale),
    );
  }

  Future<void> _locale(LocaleChanged event, Emitter<SettingsState> emit) async {
    final next = state.copyWith(locale: event.locale);
    emit(next);
    await repository.save(
      SettingsValue(themeMode: next.themeMode, locale: next.locale),
    );
  }

  Future<void> _reset(SettingsReset event, Emitter<SettingsState> emit) async {
    await repository.reset();
    emit(const SettingsState(ready: true));
  }
}
