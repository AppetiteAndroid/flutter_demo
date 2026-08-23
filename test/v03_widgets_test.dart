import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/core/connectivity/connectivity_service.dart';
import 'package:flutter_starter/core/design_system/app_theme.dart';
import 'package:flutter_starter/core/design_system/app_tokens.dart';
import 'package:flutter_starter/core/design_system/components.dart';
import 'package:flutter_starter/core/sync/sync_models.dart';
import 'package:flutter_starter/features/offline_tasks/domain/offline_task.dart';
import 'package:flutter_starter/features/offline_tasks/presentation/offline_status_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final variant in [
    (
      locale: const Locale('en'),
      theme: AppTheme.light(),
      text: 'Offline — local data remains available',
    ),
    (
      locale: const Locale('ru'),
      theme: AppTheme.dark(),
      text: 'Офлайн — локальные данные доступны',
    ),
  ]) {
    testWidgets(
      'offline status is localized and tokenized for ${variant.locale.languageCode}',
      (tester) async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ru')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            startLocale: variant.locale,
            saveLocale: false,
            child: Builder(
              builder: (context) => MaterialApp(
                theme: variant.theme,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: Scaffold(
                  body: OfflineStatusPanel(
                    connectivity: const BackendConnectivity(
                      BackendConnectivityStatus.interfaceUnavailable,
                    ),
                    sync: const SyncEngineState(SyncPhase.offline),
                    summary: OfflineSyncSummary(
                      pendingCount: 2,
                      blockedCount: 1,
                      lastSuccessfulSyncAt: DateTime.utc(2026),
                    ),
                    onSync: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(variant.text), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off_outlined));
        expect(icon.color, AppColors.light.warning);
        if (variant.theme.brightness == Brightness.dark) {
          expect(icon.color, AppColors.dark.warning);
        }
      },
    );
  }

  testWidgets('permanent failure and conflict provide recovery actions', (
    tester,
  ) async {
    final task = OfflineTask(
      id: 'task',
      ownerUserId: 'owner',
      title: 'Conflict',
      isCompleted: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      syncStatus: OfflineTaskSyncStatus.conflict,
      isDeleted: false,
      serverVersion: 1,
      blockedOperationId: 'operation',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TaskFailurePanel(
            task: task,
            onRetry: () {},
            onUseServer: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppButton), findsNWidgets(2));
  });
}
