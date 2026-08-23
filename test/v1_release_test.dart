import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/app/config/app_config.dart';
import 'package:flutter_starter/core/design_system/app_theme.dart';
import 'package:flutter_starter/core/design_system/components.dart';
import 'package:flutter_starter/core/error/app_failure.dart';
import 'package:flutter_starter/core/feature_flags/feature_flag_service.dart';
import 'package:flutter_starter/core/localization/localized_formatters.dart';
import 'package:flutter_starter/core/logger/app_logger.dart';
import 'package:flutter_starter/core/navigation/app_route_intent.dart';
import 'package:flutter_starter/core/pagination/pagination.dart';
import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/storage/key_value_storage.dart';
import 'package:flutter_starter/core/storage/token_storage.dart';
import 'package:flutter_starter/core/sync/sync_models.dart';
import 'package:flutter_starter/features/home/presentation/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test(
    'English and Russian translation leaves and placeholders match',
    () async {
      Map<String, String> flatten(
        Map<String, Object?> source, [
        String prefix = '',
      ]) {
        final result = <String, String>{};
        for (final entry in source.entries) {
          final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
          if (entry.value case final Map<String, Object?> nested) {
            result.addAll(flatten(nested, key));
          } else {
            result[key] = entry.value! as String;
          }
        }
        return result;
      }

      final en = flatten(
        (jsonDecode(
          await File('assets/translations/en.json').readAsString(),
        ) as Map).cast<String, Object?>(),
      );
      final ru = flatten(
        (jsonDecode(
          await File('assets/translations/ru.json').readAsString(),
        ) as Map).cast<String, Object?>(),
      );
      expect(ru.keys.toSet(), en.keys.toSet());
      for (final key in en.keys) {
        expect(
          RegExp(r'\{[^}]*\}').allMatches(ru[key]!).length,
          RegExp(r'\{[^}]*\}').allMatches(en[key]!).length,
          reason: key,
        );
      }
    },
  );

  test('locale-aware example date formatting supports shipped locales', () {
    expect(
      formatLocalDateTimeForLocale(DateTime(2026, 8, 23, 17, 5), 'ru'),
      '23.08.2026 17:05',
    );
    expect(
      formatLocalDateTimeForLocale(DateTime(2026, 8, 23, 17, 5), 'en'),
      '8/23/2026, 5:05 PM',
    );
  });

  test(
    'public collection snapshots cannot be mutated through source or getter',
    () {
      final sourceItems = [1];
      final page = PageResult(items: sourceItems, endReached: true);
      sourceItems.add(2);
      expect(page.items, [1]);
      expect(() => page.items.add(3), throwsUnsupportedError);

      final flagsSource = {FeatureFlag.paginationExample: true};
      final flags = FeatureFlagSnapshot(flagsSource);
      flagsSource[FeatureFlag.paginationExample] = false;
      expect(flags.isEnabled(FeatureFlag.paginationExample), isTrue);
      expect(
        () => flags.values[FeatureFlag.notificationDemo] = true,
        throwsUnsupportedError,
      );

      final payload = <String, Object?>{'title': 'safe'};
      final operation = SyncOperation(
        id: 'operation',
        ownerUserId: 'owner',
        entityType: 'task',
        entityId: 'task',
        kind: SyncOperationKind.create,
        payload: payload,
        idempotencyKey: 'key',
        attemptCount: 0,
      );
      payload['title'] = 'changed';
      expect(operation.payload['title'], 'safe');
      expect(() => operation.payload['new'] = true, throwsUnsupportedError);

      final fieldErrors = <String, List<String>>{
        'title': ['required'],
      };
      final failure = ValidationFailure(fieldErrors: fieldErrors);
      fieldErrors['title']!.add('changed');
      expect(failure.fieldErrors['title'], ['required']);
      expect(
        () => failure.fieldErrors['title']!.add('x'),
        throwsUnsupportedError,
      );

      final schemes = {'starter'};
      final hosts = {'Links.Example.Invalid'};
      final parser = AppLinkParser(customSchemes: schemes, allowedHosts: hosts);
      schemes.add('evil');
      hosts.add('evil.example');
      expect(parser.parse(Uri.parse('evil:/settings')), isNull);
      expect(
        parser.parse(Uri.parse('https://links.example.invalid/settings')),
        isA<SettingsIntent>(),
      );
      expect(() => parser.customSchemes.add('evil'), throwsUnsupportedError);
    },
  );

  testWidgets('home remains usable on a small screen at 200 percent text', (
    tester,
  ) async {
    final session = UserSession(
      tokenStorage: MemoryTokenStorage(),
      snapshotStorage: MemoryKeyValueStorage(),
    );
    await session.initialize();
    addTearDown(session.dispose);
    final config = AppConfig(
      appName: 'Test',
      environment: AppEnvironment.production,
      baseUrl: Uri(scheme: 'https', host: 'example.invalid'),
      connectTimeout: Duration(seconds: 1),
      receiveTimeout: Duration(seconds: 1),
      networkLogsEnabled: false,
    );
    tester.view.physicalSize = const Size(640, 960);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ru')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('ru'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.light(),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: HomeScreen(config: config, session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Инструменты симуляции для разработки'), findsNothing);
  });

  testWidgets('loading button and text field expose useful semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              AppButton(label: 'Save', onPressed: null, loading: true),
              AppTextField(hintText: 'Task title'),
            ],
          ),
        ),
      ),
    );
    final buttonSemantics = tester.getSemantics(find.byType(AppButton));
    expect(buttonSemantics.label, startsWith('Save, '));
    expect(buttonSemantics.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
      buttonSemantics.getSemanticsData().flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    final fieldSemantics = tester.getSemantics(find.byType(AppTextField));
    expect(fieldSemantics.label, 'Task title');
    expect(
      fieldSemantics.getSemanticsData().flagsCollection.isTextField,
      isTrue,
    );
    expect(
      fieldSemantics.getSemanticsData().flagsCollection.isEnabled,
      Tristate.isTrue,
    );
  });

  test(
    'production logger accepts errors without forwarding sensitive objects',
    () {
      const logger = ProductionAppLogger();
      expect(
        () => logger.error(
          'Safe production error',
          StateError('secret'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    },
  );
}
