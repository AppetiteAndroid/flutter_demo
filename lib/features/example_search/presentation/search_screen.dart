import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/components.dart';
import '../data/search_repository.dart';
import 'search_bloc.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'search.title'.tr(),
    body: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          AppTextField(
            hintText: 'search.hint'.tr(),
            onChanged: (value) =>
                context.read<SearchBloc>().add(SearchQueryChanged(value)),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) => switch (state.result) {
                SearchIdle() => AppEmptyView(
                  message: 'search.empty_query'.tr(),
                ),
                SearchLoading() => const AppLoader(),
                SearchData(:final items) when items.isEmpty => AppEmptyView(
                  message: 'search.no_results'.tr(),
                ),
                SearchData(:final items) => ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) =>
                      ListTile(title: Text(items[index])),
                ),
                SearchFailed() => AppErrorView(
                  message: 'search.error'.tr(),
                  onRetry: () =>
                      context.read<SearchBloc>().add(const SearchRetried()),
                ),
              },
            ),
          ),
        ],
      ),
    ),
  );
}
