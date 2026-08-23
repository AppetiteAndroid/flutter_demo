import 'dart:convert';

import 'package:rxdart/rxdart.dart';

import '../storage/key_value_storage.dart';
import '../storage/token_storage.dart';

enum AuthenticationStatus { initializing, guest, authenticated }

enum SubscriptionStatus { unknown, free, trial, active, gracePeriod, expired }

class User {
  const User({required this.id, required this.email, this.displayName});
  final String id, email;
  final String? displayName;
  User copyWith({String? email, String? displayName}) => User(
    id: id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
  };
  static User? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'], email = value['email'];
    return id is String && email is String
        ? User(
            id: id,
            email: email,
            displayName: value['displayName'] as String?,
          )
        : null;
  }
}

class UserSubscription {
  const UserSubscription({
    required this.status,
    this.productId,
    this.expiresAt,
    this.willRenew = false,
    this.source,
  });
  final SubscriptionStatus status;
  final String? productId, source;
  final DateTime? expiresAt;
  final bool willRenew;
  Map<String, Object?> toJson() => {
    'status': status.name,
    'productId': productId,
    'expiresAt': expiresAt?.toIso8601String(),
    'willRenew': willRenew,
    'source': source,
  };
  static UserSubscription? fromJson(Object? value) {
    if (value is! Map) return null;
    final status = SubscriptionStatus.values
        .where((s) => s.name == value['status'])
        .firstOrNull;
    if (status == null) return null;
    return UserSubscription(
      status: status,
      productId: value['productId'] as String?,
      expiresAt: DateTime.tryParse(value['expiresAt'] as String? ?? ''),
      willRenew: value['willRenew'] == true,
      source: value['source'] as String?,
    );
  }
}

class UserSessionState {
  const UserSessionState({
    required this.authenticationStatus,
    required this.subscriptionStatus,
    this.user,
    this.subscription,
    this.tokenRevision = 0,
  });
  const UserSessionState.initializing()
    : this(
        authenticationStatus: AuthenticationStatus.initializing,
        subscriptionStatus: SubscriptionStatus.unknown,
      );
  final AuthenticationStatus authenticationStatus;
  final SubscriptionStatus subscriptionStatus;
  final User? user;
  final UserSubscription? subscription;
  final int tokenRevision;
  bool get isAuthenticated =>
      authenticationStatus == AuthenticationStatus.authenticated;
  bool get hasPremiumAccess => {
    SubscriptionStatus.trial,
    SubscriptionStatus.active,
    SubscriptionStatus.gracePeriod,
  }.contains(subscriptionStatus);
  UserSessionState copyWith({
    AuthenticationStatus? authenticationStatus,
    SubscriptionStatus? subscriptionStatus,
    User? user,
    UserSubscription? subscription,
    bool clearUser = false,
    bool clearSubscription = false,
    int? tokenRevision,
  }) => UserSessionState(
    authenticationStatus: authenticationStatus ?? this.authenticationStatus,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    user: clearUser ? null : user ?? this.user,
    subscription: clearSubscription ? null : subscription ?? this.subscription,
    tokenRevision: tokenRevision ?? this.tokenRevision,
  );
}

class UserSession {
  UserSession({required this.tokenStorage, required this.snapshotStorage});
  final TokenStorage tokenStorage;
  final KeyValueStorage snapshotStorage;
  static const _key = 'session.snapshot';
  final BehaviorSubject<UserSessionState> _subject = BehaviorSubject.seeded(
    const UserSessionState.initializing(),
  );
  Stream<UserSessionState> get stream => _subject.stream.distinct();
  UserSessionState get current => _subject.value;
  User? get user => current.user;
  bool get isAuthenticated => current.isAuthenticated;
  bool get hasPremiumAccess => current.hasPremiumAccess;
  Future<void> initialize() async {
    final tokens = await tokenStorage.read();
    final raw = snapshotStorage.getString(_key);
    if (tokens == null || raw == null) {
      _subject.add(
        const UserSessionState(
          authenticationStatus: AuthenticationStatus.guest,
          subscriptionStatus: SubscriptionStatus.unknown,
        ),
      );
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, Object?>;
      final user = User.fromJson(map['user']);
      final sub = UserSubscription.fromJson(map['subscription']);
      if (user == null) throw const FormatException();
      _subject.add(
        UserSessionState(
          authenticationStatus: AuthenticationStatus.authenticated,
          subscriptionStatus: sub?.status ?? SubscriptionStatus.unknown,
          user: user,
          subscription: sub,
        ),
      );
    } catch (_) {
      await invalidate();
    }
  }

  Future<void> setAuthenticated({
    required User user,
    required TokenPair tokens,
    UserSubscription? subscription,
  }) async {
    await tokenStorage.write(tokens);
    final state = UserSessionState(
      authenticationStatus: AuthenticationStatus.authenticated,
      subscriptionStatus: subscription?.status ?? SubscriptionStatus.unknown,
      user: user,
      subscription: subscription,
      tokenRevision: current.tokenRevision + 1,
    );
    _subject.add(state);
    await _persist(state);
  }

  Future<void> updateUser(User user) async {
    final next = current.copyWith(user: user);
    _subject.add(next);
    await _persist(next);
  }

  Future<void> updateSubscription(UserSubscription subscription) async {
    final next = current.copyWith(
      subscription: subscription,
      subscriptionStatus: subscription.status,
    );
    _subject.add(next);
    await _persist(next);
  }

  void notifyTokenRefreshed() {
    if (current.isAuthenticated) {
      _subject.add(current.copyWith(tokenRevision: current.tokenRevision + 1));
    }
  }

  Future<void> logout() => invalidate();
  Future<void> invalidate() async {
    await tokenStorage.clear();
    await snapshotStorage.remove(_key);
    _subject.add(
      const UserSessionState(
        authenticationStatus: AuthenticationStatus.guest,
        subscriptionStatus: SubscriptionStatus.unknown,
      ),
    );
  }

  Future<void> _persist(UserSessionState state) => snapshotStorage.setString(
    _key,
    jsonEncode({
      'user': state.user?.toJson(),
      'subscription': state.subscription?.toJson(),
    }),
  );
  Future<void> dispose() => _subject.close();
}
