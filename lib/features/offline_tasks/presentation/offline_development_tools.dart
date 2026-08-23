import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/components.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/realtime/websocket_transport.dart';
import '../../../core/session/user_session.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_remote_data_source.dart';
import '../../../core/sync/sync_store.dart';

class OfflineDevelopmentTools extends StatelessWidget {
  const OfflineDevelopmentTools({
    super.key,
    required this.connectivity,
    required this.remote,
    required this.transport,
    required this.syncEngine,
    required this.realtime,
    required this.store,
    required this.database,
    required this.session,
  });

  final FakeConnectivityService connectivity;
  final FakeSyncRemoteDataSource remote;
  final FakeWebSocketTransport transport;
  final SyncEngine syncEngine;
  final RealtimeClient realtime;
  final SyncStore store;
  final AppDatabase database;
  final UserSession session;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text('offline.dev.title'.tr()),
    childrenPadding: const EdgeInsets.all(AppSpacing.md),
    children: [
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          AppButton(
            label: 'offline.dev.online'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: () => connectivity.simulate(
              const BackendConnectivity(
                BackendConnectivityStatus.backendReachable,
              ),
            ),
          ),
          AppButton(
            label: 'offline.dev.offline'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: () => connectivity.simulate(
              const BackendConnectivity(
                BackendConnectivityStatus.interfaceUnavailable,
              ),
            ),
          ),
          AppButton(
            label: 'offline.dev.backend_down'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: () => connectivity.simulate(
              const BackendConnectivity(
                BackendConnectivityStatus.backendUnreachable,
              ),
            ),
          ),
          for (final scenario in [
            FakeSyncScenario.success,
            FakeSyncScenario.offline,
            FakeSyncScenario.validationFailure,
            FakeSyncScenario.conflict,
            FakeSyncScenario.rateLimited,
          ])
            AppButton(
              label: 'offline.dev.next_${scenario.name}'.tr(),
              intent: AppButtonIntent.secondary,
              onPressed: () => remote.enqueue(scenario),
            ),
          AppButton(
            label: 'offline.dev.latency'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: () => remote.latency = remote.latency == Duration.zero
                ? const Duration(seconds: 2)
                : Duration.zero,
          ),
          AppButton(
            label: 'offline.actions.sync'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: syncEngine.requestSync,
          ),
          AppButton(
            label: 'offline.dev.inspect'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: () => _inspect(context),
          ),
          AppButton(
            label: 'offline.realtime.connect'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: realtime.connect,
          ),
          AppButton(
            label: 'offline.realtime.disconnect'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: realtime.disconnect,
          ),
          AppButton(
            label: 'offline.dev.socket_close'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: transport.latest?.unexpectedClose,
          ),
          AppButton(
            label: 'offline.dev.socket_message'.tr(),
            intent: AppButtonIntent.secondary,
            onPressed: () => transport.latest?.incoming(
              jsonEncode({
                'version': 1,
                'type': 'demo_task.changed',
                'id': 'dev-${DateTime.now().microsecondsSinceEpoch}',
                'timestamp': DateTime.now().toUtc().toIso8601String(),
                'payload': {'taskId': 'dev', 'serverVersion': 1},
              }),
            ),
          ),
          AppButton(
            label: 'offline.dev.reset'.tr(),
            intent: AppButtonIntent.destructive,
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
    ],
  );

  Future<void> _inspect(BuildContext context) async {
    final owner = session.user?.id;
    final items = owner == null ? const [] : await store.inspect(owner);
    if (!context.mounted) return;
    await AppDialog.show<void>(
      context,
      title: 'offline.dev.inspect'.tr(),
      content: SizedBox(
        width: double.maxFinite,
        child: items.isEmpty
            ? Text('offline.dev.outbox_empty'.tr())
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text('${item.kind.name} · ${item.entityId}'),
                      subtitle: Text(
                        'offline.dev.outbox_item'.tr(
                          args: [
                            '${item.attemptCount}',
                            item.safeErrorCode ?? '-',
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('offline.actions.close'.tr()),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await AppDialog.show<bool>(
      context,
      title: 'offline.dev.reset'.tr(),
      content: Text('offline.dev.reset_confirm'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('offline.actions.cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('offline.actions.reset'.tr()),
        ),
      ],
    );
    if (confirmed == true) {
      await database.developmentReset(allowDestructiveReset: true);
    }
  }
}
