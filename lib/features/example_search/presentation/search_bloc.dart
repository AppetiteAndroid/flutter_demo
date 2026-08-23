import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/search_repository.dart';

sealed class SearchEvent {
  const SearchEvent();
}

class SearchStarted extends SearchEvent {
  const SearchStarted();
}

class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);
  final String query;
}

class SearchRetried extends SearchEvent {
  const SearchRetried();
}

class SearchState {
  const SearchState({this.result = const SearchIdle()});
  final SearchResult result;
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this.repository) : super(const SearchState()) {
    on<SearchStarted>(
      (event, emit) => emit.forEach(
        repository.results,
        onData: (result) => SearchState(result: result),
      ),
    );
    on<SearchQueryChanged>((event, emit) => repository.setQuery(event.query));
    on<SearchRetried>((event, emit) => repository.retry());
  }
  final SearchRepository repository;
  @override
  Future<void> close() async {
    await repository.dispose();
    return super.close();
  }
}
