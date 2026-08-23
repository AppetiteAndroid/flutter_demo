sealed class AppRouteIntent {
  const AppRouteIntent();
  bool get requiresAuthentication => false;
}

final class HomeIntent extends AppRouteIntent {
  const HomeIntent();
}

final class SettingsIntent extends AppRouteIntent {
  const SettingsIntent();
}

final class SearchIntent extends AppRouteIntent {
  const SearchIntent({this.query});
  final String? query;
}

final class AccountDetailsIntent extends AppRouteIntent {
  const AccountDetailsIntent(this.id);
  final int id;
  @override
  bool get requiresAuthentication => true;
}

class AppLinkParser {
  AppLinkParser({
    required Set<String> customSchemes,
    required Set<String> allowedHosts,
  }) : customSchemes = Set.unmodifiable(customSchemes),
       allowedHosts = Set.unmodifiable(
         allowedHosts.map((host) => host.toLowerCase()),
       );
  final Set<String> customSchemes, allowedHosts;
  AppRouteIntent? parse(Uri uri) {
    final custom = customSchemes.contains(uri.scheme);
    final web =
        uri.scheme == 'https' && allowedHosts.contains(uri.host.toLowerCase());
    if (!custom && !web) return null;
    final segments = uri.pathSegments
        .where((value) => value.isNotEmpty)
        .toList();
    if (segments.isEmpty || segments.singleOrNull == 'home') {
      return const HomeIntent();
    }
    if (segments.length == 1 && segments[0] == 'settings') {
      return const SettingsIntent();
    }
    if (segments.length == 1 && segments[0] == 'search') {
      final query = uri.queryParameters['q']?.trim();
      return SearchIntent(query: query?.isEmpty == true ? null : query);
    }
    if (segments.length == 2 && segments[0] == 'account') {
      final id = int.tryParse(segments[1]);
      if (id != null && id > 0) return AccountDetailsIntent(id);
    }
    return null;
  }

  AppRouteIntent? parsePayload(String? payload) {
    if (payload == null || payload.length > 2048) return null;
    final uri = Uri.tryParse(payload);
    return uri == null ? null : parse(uri);
  }
}
