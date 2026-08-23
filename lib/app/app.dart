import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/design_system/app_theme.dart';
import '../features/settings/presentation/settings_bloc.dart';
import 'config/app_config.dart';

class StarterApp extends StatelessWidget {
  const StarterApp({
    super.key,
    required this.config,
    required this.settingsBloc,
    required this.router,
  });
  final AppConfig config;
  final SettingsBloc settingsBloc;
  final GoRouter router;
  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: settingsBloc,
    child: BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) => MaterialApp.router(
        title: config.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: state.themeMode,
        locale: state.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        routerConfig: router,
      ),
    ),
  );
}
