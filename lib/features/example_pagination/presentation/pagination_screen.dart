import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components.dart';
import '../../../core/pagination/pagination.dart';
import '../data/demo_pagination_repository.dart';

class PaginationScreen extends StatelessWidget {
  const PaginationScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'pagination.title'.tr(),
    body: BlocBuilder<PaginationBloc<DemoItem, int>, PaginationState<DemoItem>>(
      builder: (context, state) {
        if (state.initialLoading) return const AppLoader();
        if (state.initialError != null && state.items.isEmpty) {
          return AppErrorView(
            message: 'pagination.error'.tr(),
            onRetry: () => context.read<PaginationBloc<DemoItem, int>>().add(
              const PaginationStarted(),
            ),
          );
        }
        if (state.items.isEmpty) {
          return AppEmptyView(message: 'pagination.empty'.tr());
        }
        return AppRefresh(
          onRefresh: () async => context
              .read<PaginationBloc<DemoItem, int>>()
              .add(const PaginationRefreshed()),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 300) {
                context.read<PaginationBloc<DemoItem, int>>().add(
                  const PaginationNextRequested(),
                );
              }
              return false;
            },
            child: ListView.builder(
              itemCount: state.items.length + 1,
              itemBuilder: (context, index) {
                if (index < state.items.length) {
                  return ListTile(title: Text(state.items[index].title));
                }
                return AppPaginationFooter(
                  state: state.loadingMore
                      ? PaginationFooterState.loading
                      : state.nextPageError != null
                      ? PaginationFooterState.error
                      : state.endReached
                      ? PaginationFooterState.end
                      : PaginationFooterState.hidden,
                  onRetry: () => context
                      .read<PaginationBloc<DemoItem, int>>()
                      .add(const PaginationNextRequested()),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}
