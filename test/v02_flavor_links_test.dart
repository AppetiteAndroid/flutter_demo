import 'dart:async';

import 'package:flutter_starter/app/config/app_config.dart';
import 'package:flutter_starter/core/navigation/app_link_service.dart';
import 'package:flutter_starter/core/navigation/app_route_intent.dart';
import 'package:flutter_test/flutter_test.dart';

class LinkSourceFake implements PlatformLinkSource {
  LinkSourceFake(this.initial);
  final Uri? initial;
  final controller = StreamController<Uri>.broadcast();
  @override
  Future<Uri?> initialUri() async => initial;
  @override
  Stream<Uri> get uriStream => controller.stream;
}

void main() {
  final parser = AppLinkParser(
    customSchemes: {'flutterstarter-dev'},
    allowedHosts: {'dev.example.invalid'},
  );
  test(
    'native and Dart flavor mismatch fails clearly',
    () => expect(
      () => AppConfig.fromEnvironment(
        values: {
          'APP_NAME': 'App',
          'ENVIRONMENT': 'development',
          'NATIVE_FLAVOR': 'production',
          'BASE_URL': 'https://example.invalid',
          'CONNECT_TIMEOUT_MS': '1',
          'RECEIVE_TIMEOUT_MS': '1',
        },
      ),
      throwsFormatException,
    ),
  );
  test('valid links parse to typed normalized intents', () {
    expect(
      parser.parse(Uri.parse('flutterstarter-dev:/settings')),
      isA<SettingsIntent>(),
    );
    final search = parser.parse(
      Uri.parse('https://dev.example.invalid/search?q=%20Bloc%20'),
    ) as SearchIntent;
    expect(search.query, 'Bloc');
    expect(parser.parse(Uri.parse('https://evil.invalid/settings')), isNull);
    expect(parser.parse(Uri.parse('flutterstarter-dev:/account/nope')), isNull);
    expect(parser.parse(Uri.parse('javascript:alert(1)')), isNull);
  });
  test('initial/runtime duplicate is suppressed', () async {
    final uri = Uri.parse('flutterstarter-dev:/settings');
    final source = LinkSourceFake(uri);
    final service = AppLinkService(source: source, parser: parser);
    final values = <AppRouteIntent>[];
    final subscription = service.intents.listen(values.add);
    await service.initialize();
    source.controller.add(uri);
    await Future<void>.delayed(Duration.zero);
    expect(values.length, 1);
    await subscription.cancel();
    await source.controller.close();
    await service.dispose();
  });
}
