Object? redactSensitive(Object? value) {
  if (value is Map) {
    return value.map((key, item) {
      final normalized = key.toString().toLowerCase().replaceAll(
        RegExp(r'[-_]'),
        '',
      );
      const secrets = {
        'authorization',
        'cookie',
        'setcookie',
        'accesstoken',
        'refreshtoken',
        'password',
        'apikey',
        'secret',
      };
      return MapEntry(
        key,
        secrets.contains(normalized) ? '<redacted>' : redactSensitive(item),
      );
    });
  }
  if (value is Iterable) {
    return value.map(redactSensitive).toList(growable: false);
  }
  return value;
}

/// Query values, fragments and URI user-info commonly carry credentials or
/// user input. Network diagnostics only need the endpoint path.
String safeUriForLog(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) return uri.path;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port${uri.path}';
}
