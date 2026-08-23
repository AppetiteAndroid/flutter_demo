import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/components.dart';
import 'settings_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'settings.title'.tr(),
    body: BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'settings.theme.title'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final item in [
            (ThemeMode.system, 'settings.theme.system'),
            (ThemeMode.light, 'settings.theme.light'),
            (ThemeMode.dark, 'settings.theme.dark'),
          ])
            AppSelectionTile(
              title: item.$2.tr(),
              value: item.$1,
              groupValue: state.themeMode,
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsBloc>().add(ThemeChanged(value));
                }
              },
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'settings.language.title'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          AppSelectionTile(
            title: 'settings.language.english'.tr(),
            value: 'en',
            groupValue: state.locale.languageCode,
            onChanged: (value) {
              if (value != null) {
                final locale = Locale(value);
                context.read<SettingsBloc>().add(LocaleChanged(locale));
                context.setLocale(locale);
              }
            },
          ),
          AppSelectionTile(
            title: 'settings.language.russian'.tr(),
            value: 'ru',
            groupValue: state.locale.languageCode,
            onChanged: (value) {
              if (value != null) {
                final locale = Locale(value);
                context.read<SettingsBloc>().add(LocaleChanged(locale));
                context.setLocale(locale);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'settings.reset'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: () {
              context.read<SettingsBloc>().add(const SettingsReset());
              context.setLocale(const Locale('en'));
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(
              '${'settings.version'.tr()}: ${snapshot.data?.version ?? '—'} (${snapshot.data?.buildNumber ?? '—'})',
            ),
          ),
        ],
      ),
    ),
  );
}
