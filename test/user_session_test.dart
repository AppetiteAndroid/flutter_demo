import 'package:flutter_starter/core/session/user_session.dart';
import 'package:flutter_starter/core/storage/key_value_storage.dart';
import 'package:flutter_starter/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session transitions, updates, logout and replays latest', () async {
    final tokens = MemoryTokenStorage(), snapshots = MemoryKeyValueStorage();
    final session = UserSession(
      tokenStorage: tokens,
      snapshotStorage: snapshots,
    );
    expect(
      session.current.authenticationStatus,
      AuthenticationStatus.initializing,
    );
    await session.initialize();
    await session.setAuthenticated(
      user: const User(id: '1', email: 'a@b.c'),
      tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
      subscription: const UserSubscription(status: SubscriptionStatus.free),
    );
    await session.updateUser(const User(id: '1', email: 'new@b.c'));
    await session.updateSubscription(
      const UserSubscription(status: SubscriptionStatus.trial),
    );
    expect(await session.stream.first, session.current);
    expect(session.user?.email, 'new@b.c');
    expect(session.hasPremiumAccess, isTrue);
    await session.logout();
    expect(session.isAuthenticated, isFalse);
    expect(tokens.value, isNull);
    await session.dispose();
  });
  for (final status in SubscriptionStatus.values) {
    test('premium derivation for ${status.name}', () {
      final state = UserSessionState(
        authenticationStatus: AuthenticationStatus.authenticated,
        subscriptionStatus: status,
      );
      expect(
        state.hasPremiumAccess,
        {
          SubscriptionStatus.trial,
          SubscriptionStatus.active,
          SubscriptionStatus.gracePeriod,
        }.contains(status),
      );
    });
  }
  test('memory tokens round trip', () async {
    final storage = MemoryTokenStorage();
    await storage.write(const TokenPair(accessToken: 'a', refreshToken: 'r'));
    expect((await storage.read())?.refreshToken, 'r');
    await storage.clear();
    expect(await storage.read(), isNull);
  });
}
