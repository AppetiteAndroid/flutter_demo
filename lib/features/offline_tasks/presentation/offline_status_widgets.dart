import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/components.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/localized_formatters.dart';
import '../../../core/sync/sync_models.dart';
import '../domain/offline_task.dart';

class OfflineStatusPanel extends StatelessWidget {
  const OfflineStatusPanel({
    super.key,
    required this.connectivity,
    required this.sync,
    required this.summary,
    required this.onSync,
  });

  final BackendConnectivity connectivity;
  final SyncEngineState sync;
  final OfflineSyncSummary summary;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final offline = {
      BackendConnectivityStatus.interfaceUnavailable,
      BackendConnectivityStatus.backendUnreachable,
    }.contains(connectivity.status);
    final syncing = sync.phase == SyncPhase.syncing;
    return Semantics(
      liveRegion: true,
      label: offline
          ? 'offline.status.offline'.tr()
          : 'offline.status.online'.tr(),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    offline
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    color: offline
                        ? context.colors.warning
                        : context.colors.success,
                    size: AppIconSize.medium,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      offline
                          ? 'offline.status.offline'.tr()
                          : syncing
                          ? 'offline.status.syncing'.tr()
                          : 'offline.status.online'.tr(),
                      style: context.textStyles.titleMedium,
                    ),
                  ),
                  if (syncing)
                    const SizedBox.square(
                      dimension: AppIconSize.small,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'offline.status.pending'.tr(args: ['${summary.pendingCount}']),
              ),
              if (summary.lastSuccessfulSyncAt != null)
                Text(
                  'offline.status.last_sync'.tr(
                    args: [
                      formatLocalDateTime(
                        context,
                        summary.lastSuccessfulSyncAt!,
                      ),
                    ],
                  ),
                  style: context.textStyles.bodySmall,
                ),
              if (summary.blockedCount > 0)
                Text(
                  'offline.status.blocked'.tr(
                    args: ['${summary.blockedCount}'],
                  ),
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'offline.actions.sync'.tr(),
                intent: AppButtonIntent.secondary,
                onPressed: syncing ? null : onSync,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskFailurePanel extends StatelessWidget {
  const TaskFailurePanel({
    super.key,
    required this.task,
    required this.onRetry,
    required this.onUseServer,
  });

  final OfflineTask task;
  final VoidCallback onRetry;
  final VoidCallback onUseServer;

  @override
  Widget build(BuildContext context) {
    final conflict = task.syncStatus == OfflineTaskSyncStatus.conflict;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.colors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            conflict
                ? 'offline.failure.conflict'.tr()
                : 'offline.failure.permanent'.tr(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppButton(
                label: conflict
                    ? 'offline.actions.keep_local'.tr()
                    : 'offline.actions.retry'.tr(),
                intent: AppButtonIntent.secondary,
                onPressed: onRetry,
              ),
              if (conflict)
                AppButton(
                  label: 'offline.actions.use_server'.tr(),
                  intent: AppButtonIntent.secondary,
                  onPressed: onUseServer,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
