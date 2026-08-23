import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:rxdart/rxdart.dart';

import 'app_route_intent.dart';

abstract interface class PlatformLinkSource {
  Future<Uri?> initialUri();
  Stream<Uri> get uriStream;
}

class AppLinksSource implements PlatformLinkSource {
  AppLinksSource([AppLinks? links]) : _links = links ?? AppLinks();
  final AppLinks _links;
  @override
  Future<Uri?> initialUri() => _links.getInitialLink();
  @override
  Stream<Uri> get uriStream => _links.uriLinkStream;
}

class AppLinkService {
  AppLinkService({required this.source, required this.parser});
  final PlatformLinkSource source;
  final AppLinkParser parser;
  final PublishSubject<AppRouteIntent> _intents = PublishSubject();
  StreamSubscription<Uri>? _subscription;
  String? _last;
  bool _disposed = false;
  Stream<AppRouteIntent> get intents => _intents.stream;
  Future<void> initialize() async {
    final initial = await source.initialUri();
    if (initial != null) _accept(initial);
    if (_disposed) return;
    _subscription = source.uriStream.listen(_accept);
  }

  void _accept(Uri uri) {
    if (_disposed || uri.toString() == _last) return;
    final intent = parser.parse(uri);
    if (intent == null) return;
    _last = uri.toString();
    _intents.add(intent);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _intents.close();
  }
}
