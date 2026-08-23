import '../../../core/pagination/pagination.dart';

class DemoItem {
  const DemoItem(this.id, this.title);
  final int id;
  final String title;
}

class DemoPaginationRepository implements PaginatedRepository<DemoItem> {
  DemoPaginationRepository({
    this.pageSize = 20,
    this.delay = const Duration(milliseconds: 150),
  });
  final int pageSize;
  final Duration delay;
  int? failPage;
  @override
  Future<PageResult<DemoItem>> load(PageRequest request) async {
    await Future<void>.delayed(delay);
    final page = request is NumberPageRequest
        ? request.page
        : int.tryParse((request as CursorPageRequest).cursor ?? '1') ?? 1;
    if (failPage == page) throw StateError('Injected page failure');
    final start = (page - 1) * pageSize;
    final items = List.generate(
      pageSize,
      (index) => DemoItem(start + index, 'Item ${start + index}'),
    );
    return PageResult(
      items: items,
      nextPage: page + 1,
      nextCursor: '${page + 1}',
      endReached: page >= 5,
    );
  }
}
