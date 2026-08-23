import 'package:rxdart/rxdart.dart';

import '../../../core/network/api_client.dart';

abstract interface class SearchDataSource {
  Future<List<String>> search(String query);
}

class InMemorySearchDataSource implements SearchDataSource {
  const InMemorySearchDataSource({
    this.delay = const Duration(milliseconds: 120),
  });
  final Duration delay;
  static const items = [
    'BLoC state management',
    'Dio networking',
    'Easy Localization',
    'GetIt dependency injection',
    'GoRouter navigation',
    'Material 3 themes',
    'RxDart streams',
    'Secure token storage',
  ];
  @override
  Future<List<String>> search(String query) async {
    await Future<void>.delayed(delay);
    if (query == 'error') throw StateError('Demo failure');
    return items.where((item) => item.toLowerCase().contains(query)).toList();
  }
}

class RemoteSearchDataSource implements SearchDataSource {
  RemoteSearchDataSource(this.client);
  final ApiClient client;
  @override
  Future<List<String>> search(String query) async {
    final result = await client.get<List<String>>(
      '/search',
      query: {'q': query},
      parser: (data) => (data as List).cast<String>(),
    );
    return result.fold(
      (value) => value,
      (failure) =>
          throw StateError(failure.message ?? failure.runtimeType.toString()),
    );
  }
}

sealed class SearchResult {
  const SearchResult();
}

class SearchIdle extends SearchResult {
  const SearchIdle();
}

class SearchLoading extends SearchResult {
  const SearchLoading();
}

class SearchData extends SearchResult {
  const SearchData(this.items);
  final List<String> items;
}

class SearchFailed extends SearchResult {
  const SearchFailed(this.error);
  final Object error;
}

class SearchRepository {
  SearchRepository(
    this.source, {
    this.debounce = const Duration(milliseconds: 350),
  }) {
    results = _queries
        .map((value) => value.trim().toLowerCase())
        .distinct()
        .debounceTime(debounce)
        .switchMap((query) {
          if (query.length < 2) return Stream.value(const SearchIdle());
          return Stream.fromFuture(source.search(query))
              .map<SearchResult>(SearchData.new)
              .startWith(const SearchLoading())
              .onErrorReturnWith((error, _) => SearchFailed(error));
        })
        .shareReplay(maxSize: 1);
  }
  final SearchDataSource source;
  final Duration debounce;
  final BehaviorSubject<String> _queries = BehaviorSubject.seeded('');
  late final Stream<SearchResult> results;
  String get currentQuery => _queries.value;
  void setQuery(String value) => _queries.add(value);
  void retry() => _queries.add('${_queries.value} ');
  Future<void> dispose() => _queries.close();
}
