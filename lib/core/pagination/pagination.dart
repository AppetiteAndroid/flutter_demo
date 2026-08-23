import 'package:flutter_bloc/flutter_bloc.dart';

sealed class PageRequest {
  const PageRequest();
}

class NumberPageRequest extends PageRequest {
  const NumberPageRequest(this.page);
  final int page;
}

class CursorPageRequest extends PageRequest {
  const CursorPageRequest(this.cursor);
  final String? cursor;
}

class PageResult<T> {
  PageResult({
    required List<T> items,
    this.nextPage,
    this.nextCursor,
    required this.endReached,
  }) : items = List.unmodifiable(items);
  final List<T> items;
  final int? nextPage;
  final String? nextCursor;
  final bool endReached;
}

abstract interface class PaginatedRepository<T> {
  Future<PageResult<T>> load(PageRequest request);
}

class PaginationState<T> {
  PaginationState({
    List<T> items = const [],
    this.initialLoading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.endReached = false,
    this.initialError,
    this.nextPageError,
    this.nextRequest = const NumberPageRequest(1),
    this.generation = 0,
  }) : items = List.unmodifiable(items);
  final List<T> items;
  final bool initialLoading, refreshing, loadingMore, endReached;
  final Object? initialError, nextPageError;
  final PageRequest nextRequest;
  final int generation;
  PaginationState<T> copyWith({
    List<T>? items,
    bool? initialLoading,
    bool? refreshing,
    bool? loadingMore,
    bool? endReached,
    Object? initialError,
    Object? nextPageError,
    PageRequest? nextRequest,
    int? generation,
    bool clearInitialError = false,
    bool clearNextError = false,
  }) => PaginationState(
    items: items ?? this.items,
    initialLoading: initialLoading ?? this.initialLoading,
    refreshing: refreshing ?? this.refreshing,
    loadingMore: loadingMore ?? this.loadingMore,
    endReached: endReached ?? this.endReached,
    initialError: clearInitialError ? null : initialError ?? this.initialError,
    nextPageError: clearNextError ? null : nextPageError ?? this.nextPageError,
    nextRequest: nextRequest ?? this.nextRequest,
    generation: generation ?? this.generation,
  );
}

sealed class PaginationEvent {
  const PaginationEvent();
}

class PaginationStarted extends PaginationEvent {
  const PaginationStarted();
}

class PaginationRefreshed extends PaginationEvent {
  const PaginationRefreshed();
}

class PaginationNextRequested extends PaginationEvent {
  const PaginationNextRequested();
}

class PaginationBloc<T, K> extends Bloc<PaginationEvent, PaginationState<T>> {
  PaginationBloc({
    required this.repository,
    required this.keyOf,
    this.initialRequest = const NumberPageRequest(1),
  }) : super(PaginationState(nextRequest: initialRequest)) {
    on<PaginationStarted>((_, emit) => _initial(emit));
    on<PaginationRefreshed>((_, emit) => _refresh(emit));
    on<PaginationNextRequested>((_, emit) => _next(emit));
  }
  final PaginatedRepository<T> repository;
  final K Function(T) keyOf;
  final PageRequest initialRequest;
  int _generation = 0;
  bool _busy = false;
  Future<void> _initial(Emitter<PaginationState<T>> emit) async {
    if (_busy) return;
    _busy = true;
    final generation = ++_generation;
    emit(state.copyWith(initialLoading: true, clearInitialError: true));
    try {
      final page = await repository.load(initialRequest);
      if (generation != _generation) return;
      emit(_fromPage(page, generation));
    } catch (error) {
      if (generation == _generation) {
        emit(state.copyWith(initialLoading: false, initialError: error));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _refresh(Emitter<PaginationState<T>> emit) async {
    final generation = ++_generation;
    _busy = true;
    emit(
      state.copyWith(
        refreshing: true,
        clearInitialError: true,
        clearNextError: true,
        generation: generation,
      ),
    );
    try {
      final page = await repository.load(initialRequest);
      if (generation != _generation) return;
      emit(_fromPage(page, generation));
    } catch (error) {
      if (generation == _generation) {
        emit(
          state.copyWith(
            refreshing: false,
            initialError: state.items.isEmpty ? error : null,
          ),
        );
      }
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  Future<void> _next(Emitter<PaginationState<T>> emit) async {
    if (_busy || state.endReached || state.items.isEmpty) return;
    _busy = true;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true, clearNextError: true));
    try {
      final page = await repository.load(state.nextRequest);
      if (generation != _generation) return;
      final byKey = <K, T>{for (final item in state.items) keyOf(item): item};
      for (final item in page.items) {
        byKey[keyOf(item)] = item;
      }
      emit(
        state.copyWith(
          items: List.unmodifiable(byKey.values),
          loadingMore: false,
          endReached: page.endReached,
          nextRequest: _nextRequest(page),
          clearNextError: true,
        ),
      );
    } catch (error) {
      if (generation == _generation) {
        emit(state.copyWith(loadingMore: false, nextPageError: error));
      }
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  PaginationState<T> _fromPage(PageResult<T> page, int generation) {
    final unique = <K, T>{for (final item in page.items) keyOf(item): item};
    return PaginationState(
      items: List.unmodifiable(unique.values),
      endReached: page.endReached,
      nextRequest: _nextRequest(page),
      generation: generation,
    );
  }

  PageRequest _nextRequest(PageResult<T> page) => page.nextCursor != null
      ? CursorPageRequest(page.nextCursor)
      : NumberPageRequest(page.nextPage ?? 1);
}
