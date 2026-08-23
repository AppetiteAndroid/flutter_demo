# Pagination

`PaginationBloc<T,K>` accepts page-number or cursor requests. It guards active
loads, de-duplicates by stable item key, invalidates stale generations on
refresh, retains content after next-page failure, and exposes separate initial,
refresh and footer states. `example_pagination` is deterministic and backend
free. Dispatch `PaginationNextRequested` near the end and
`PaginationRefreshed` from pull-to-refresh.
