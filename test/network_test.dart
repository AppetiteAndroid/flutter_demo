import 'package:dio/dio.dart';
import 'package:flutter_starter/core/error/app_failure.dart';
import 'package:flutter_starter/core/logger/redactor.dart';
import 'package:flutter_starter/core/network/auth_interceptor.dart';
import 'package:flutter_starter/core/network/failure_mapper.dart';
import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/storage/key_value_storage.dart';
import 'package:flutter_starter/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class AlwaysUnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{}',
    401,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class RefreshFake implements TokenRefreshService {
  int calls = 0;
  final TokenPair? result;
  RefreshFake(this.result);
  @override
  Future<TokenPair?> refresh(String refreshToken) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return result;
  }
}

void main() {
  test('maps representative Dio failures', () {
    final request = RequestOptions(path: '/');
    expect(
      mapDioFailure(
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        ),
      ),
      isA<NetworkFailure>(),
    );
    expect(
      mapDioFailure(
        DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 401),
        ),
      ),
      isA<UnauthorizedFailure>(),
    );
    expect(
      mapDioFailure(
        DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 503),
        ),
      ),
      isA<ServerFailure>(),
    );
  });
  test('redacts nested secrets', () {
    final value = redactSensitive({
      'Authorization': 'Bearer secret',
      'body': {'password': 'secret', 'safe': 'ok'},
    }) as Map;
    expect(value.toString(), isNot(contains('secret')));
    expect((value['body'] as Map)['safe'], 'ok');
  });

  test('safe URI logging strips credentials, query and fragment', () {
    final safe = safeUriForLog(
      Uri.parse(
        'https://user:password@example.invalid/search?q=private&token=secret#fragment',
      ),
    );
    expect(safe, 'https://example.invalid/search');
    expect(safe, isNot(contains('private')));
    expect(safe, isNot(contains('password')));
  });
  test('single flight shares one refresh', () async {
    final storage = MemoryTokenStorage();
    await storage.write(
      const TokenPair(accessToken: 'old', refreshToken: 'refresh'),
    );
    final service = RefreshFake(
      const TokenPair(accessToken: 'new', refreshToken: 'new-refresh'),
    );
    final refresher = SingleFlightTokenRefresher(service, storage);
    final results = await Future.wait([
      refresher.refresh(),
      refresher.refresh(),
      refresher.refresh(),
    ]);
    expect(service.calls, 1);
    expect(results.every((value) => value?.accessToken == 'new'), isTrue);
  });

  test('terminal refresh failure invalidates session', () async {
    final tokens = MemoryTokenStorage();
    await tokens.write(
      const TokenPair(accessToken: 'old', refreshToken: 'bad'),
    );
    final session = UserSession(
      tokenStorage: tokens,
      snapshotStorage: MemoryKeyValueStorage(),
    );
    await session.initialize();
    await session.setAuthenticated(
      user: const User(id: '1', email: 'a@b.c'),
      tokens: const TokenPair(accessToken: 'old', refreshToken: 'bad'),
    );
    final dio = Dio();
    dio.httpClientAdapter = AlwaysUnauthorizedAdapter();
    dio.interceptors.add(
      AuthInterceptor(
        dio,
        tokens: tokens,
        refresher: SingleFlightTokenRefresher(RefreshFake(null), tokens),
        session: session,
      ),
    );
    await expectLater(
      dio.get<Object?>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(session.current.authenticationStatus, AuthenticationStatus.guest);
    expect(tokens.value, isNull);
    await session.dispose();
  });
}
