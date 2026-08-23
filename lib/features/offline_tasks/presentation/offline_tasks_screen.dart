import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/components.dart';
import '../../../core/realtime/realtime_models.dart';
import '../domain/offline_task.dart';
import 'offline_status_widgets.dart';
import 'offline_tasks_bloc.dart';

class OfflineTasksScreen extends StatefulWidget {
  const OfflineTasksScreen({super.key, this.developmentTools});

  final Widget? developmentTools;

  @override
  State<OfflineTasksScreen> createState() => _OfflineTasksScreenState();
}

class _OfflineTasksScreenState extends State<OfflineTasksScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<OfflineTasksBloc, OfflineTasksState>(
        listenWhen: (previous, current) =>
            previous.commandFailure != current.commandFailure &&
            current.commandFailure != null,
        listener: (context, state) => AppSnackBar.show(
          context,
          'offline.errors.${state.commandFailure}'.tr(),
        ),
        builder: (context, state) => AppScaffold(
          title: 'offline.title'.tr(),
          actions: [
            IconButton(
              tooltip: state.realtime.phase == RealtimePhase.connected
                  ? 'offline.realtime.disconnect'.tr()
                  : 'offline.realtime.connect'.tr(),
              onPressed: () => context.read<OfflineTasksBloc>().add(
                const RealtimeConnectionToggled(),
              ),
              icon: Icon(
                state.realtime.phase == RealtimePhase.connected
                    ? Icons.sensors
                    : Icons.sensors_off,
                size: AppIconSize.medium,
              ),
            ),
          ],
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: OfflineStatusPanel(
                  connectivity: state.connectivity,
                  sync: state.sync,
                  summary: state.summary,
                  onSync: () => context.read<OfflineTasksBloc>().add(
                    const OfflineSyncRequested(),
                  ),
                ),
              ),
              Expanded(
                child: state.tasks.isEmpty
                    ? AppEmptyView(message: 'offline.empty'.tr())
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: state.tasks.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) =>
                            _TaskTile(task: state.tasks[index]),
                      ),
              ),
              if (widget.developmentTools != null) widget.developmentTools!,
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final compact =
                        constraints.maxWidth < 420 || textScale > 1.3;
                    final field = AppTextField(
                      controller: _controller,
                      hintText: 'offline.add_hint'.tr(),
                    );
                    final add = AppButton(
                      label: 'offline.actions.add'.tr(),
                      onPressed: () {
                        final value = _controller.text;
                        context.read<OfflineTasksBloc>().add(
                          OfflineTaskAdded(value),
                        );
                        _controller.clear();
                      },
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field,
                          const SizedBox(height: AppSpacing.xs),
                          add,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: AppSpacing.xs),
                        add,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final OfflineTask task;

  @override
  Widget build(BuildContext context) {
    final operationId = task.blockedOperationId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: task.isCompleted,
                  onChanged: (_) => context.read<OfflineTasksBloc>().add(
                    OfflineTaskToggled(task),
                  ),
                ),
                Expanded(child: Text(task.title)),
                IconButton(
                  tooltip: 'offline.actions.delete'.tr(),
                  onPressed: () => context.read<OfflineTasksBloc>().add(
                    OfflineTaskDeleted(task.id),
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: AppIconSize.medium,
                  ),
                ),
              ],
            ),
            if (operationId != null)
              TaskFailurePanel(
                task: task,
                onRetry: () => context.read<OfflineTasksBloc>().add(
                  task.syncStatus == OfflineTaskSyncStatus.conflict
                      ? OfflineTaskConflictResolved(
                          operationId,
                          TaskConflictResolution.retryClient,
                        )
                      : OfflineTaskRetried(operationId),
                ),
                onUseServer: () => context.read<OfflineTasksBloc>().add(
                  OfflineTaskConflictResolved(
                    operationId,
                    TaskConflictResolution.useServer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
