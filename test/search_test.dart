import 'dart:async';

import 'package:flutter_starter/features/example_search/data/search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class ControlledSource implements SearchDataSource {
  final calls = <String>[];
  final completers = <String, Completer<List<String>>>{};
  @override
  Future<List<String>> search(String query) {
    calls.add(query);
    return (completers[query] ??= Completer<List<String>>()).future;
  }
}

void main() {
  test('debounces, distincts and switches to latest', () async {
    final source = ControlledSource();
    final repository = SearchRepository(
      source,
      debounce: const Duration(milliseconds: 1),
    );
    final values = <SearchResult>[];
    final subscription = repository.results.listen(values.add);
    repository.setQuery(' old ');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    repository.setQuery('new');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    source.completers['new']!.complete(['new result']);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    source.completers['old']!.complete(['stale']);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(source.calls, ['old', 'new']);
    expect((values.last as SearchData).items, ['new result']);
    repository.setQuery('new');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(source.calls, ['old', 'new']);
    await subscription.cancel();
    await repository.dispose();
  });
}
