import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});
  final String accessToken, refreshToken;
}

abstract interface class TokenStorage {
  Future<TokenPair?> read();
  Future<void> write(TokenPair pair);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this.storage);
  final FlutterSecureStorage storage;
  static const _access = 'access_token', _refresh = 'refresh_token';
  @override
  Future<TokenPair?> read() async {
    final values = await Future.wait([
      storage.read(key: _access),
      storage.read(key: _refresh),
    ]);
    return values[0] == null || values[1] == null
        ? null
        : TokenPair(accessToken: values[0]!, refreshToken: values[1]!);
  }

  @override
  Future<void> write(TokenPair pair) async {
    await storage.write(key: _access, value: pair.accessToken);
    await storage.write(key: _refresh, value: pair.refreshToken);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      storage.delete(key: _access),
      storage.delete(key: _refresh),
    ]);
  }
}

class MemoryTokenStorage implements TokenStorage {
  TokenPair? value;
  @override
  Future<TokenPair?> read() async => value;
  @override
  Future<void> write(TokenPair pair) async {
    value = pair;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
