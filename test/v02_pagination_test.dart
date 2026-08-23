import 'dart:async';

import 'package:flutter_starter/core/pagination/pagination.dart';
import 'package:flutter_test/flutter_test.dart';

class Repo implements PaginatedRepository<int> {
  int calls = 0;
  final Map<int, Completer<PageResult<int>>> pending = {};
  @override
  Future<PageResult<int>> load(PageRequest request) {
    calls++;
    final page = request is NumberPageRequest
        ? request.page
        : int.parse((request as CursorPageRequest).cursor ?? '1');
    return (pending[page] ??= Completer()).future;
  }
}

void main() {
  test(
    'initial, duplicate guard, load more de-duplicates and retains errors',
    () async {
      final repo = Repo();
      final bloc = PaginationBloc<int, int>(
        repository: repo,
        keyOf: (item) => item,
      );
      bloc.add(const PaginationStarted());
      await Future<void>.delayed(Duration.zero);
      repo.pending[1]!.complete(
        PageResult(items: [1, 2], nextPage: 2, endReached: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items, [1, 2]);
      bloc.add(const PaginationNextRequested());
      bloc.add(const PaginationNextRequested());
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 2);
      repo.pending[2]!.complete(
        PageResult(items: [2, 3], nextPage: 3, endReached: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items, [1, 2, 3]);
      bloc.add(const PaginationNextRequested());
      await Future<void>.delayed(Duration.zero);
      repo.pending[3]!.completeError(StateError('next'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items, [1, 2, 3]);
      expect(bloc.state.nextPageError, isNotNull);
      await bloc.close();
    },
  );
  test('refresh rejects stale next-page response', () async {
    final repo = Repo();
    final bloc = PaginationBloc<int, int>(
      repository: repo,
      keyOf: (item) => item,
    );
    bloc.add(const PaginationStarted());
    await Future<void>.delayed(Duration.zero);
    repo.pending[1]!.complete(
      PageResult(items: [1], nextPage: 2, endReached: false),
    );
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PaginationNextRequested());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PaginationRefreshed());
    await Future<void>.delayed(Duration.zero);
    repo.pending[2]!.complete(
      PageResult(items: [2], nextPage: 3, endReached: false),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.items, [1]);
    await bloc.close();
  });
}
