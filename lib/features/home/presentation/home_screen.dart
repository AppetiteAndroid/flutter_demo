import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_config.dart';
import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/components.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/storage/token_storage.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.config,
    required this.session,
    this.notifications,
  });
  final AppConfig config;
  final UserSession session;
  final LocalNotificationService? notifications;
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'home.title'.tr(),
    body: StreamBuilder<UserSessionState>(
      stream: session.stream,
      initialData: session.current,
      builder: (context, snapshot) {
        final state = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'home.welcome'.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            _row(
              'home.environment'.tr(),
              'home.environment_values.${config.environment.name}'.tr(),
            ),
            _row(
              'home.auth'.tr(),
              'home.auth_status.${state.authenticationStatus.name}'.tr(),
            ),
            _row(
              'home.subscription'.tr(),
              _subscriptionLabel(state.subscriptionStatus).tr(),
            ),
            _row(
              'home.premium'.tr(),
              state.hasPremiumAccess ? 'home.yes'.tr() : 'home.no'.tr(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'nav.search'.tr(),
              onPressed: () => context.pushNamed('search'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'nav.offline_tasks'.tr(),
              intent: AppButtonIntent.secondary,
              onPressed: () => context.pushNamed('offlineTasks'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'nav.settings'.tr(),
              intent: AppButtonIntent.secondary,
              onPressed: () => context.pushNamed('settings'),
            ),
            if (kDebugMode &&
                config.environment == AppEnvironment.development) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'home.demo'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AppButton(
                    label: 'home.guest'.tr(),
                    intent: AppButtonIntent.secondary,
                    onPressed: session.invalidate,
                  ),
                  for (final status in [
                    SubscriptionStatus.free,
                    SubscriptionStatus.trial,
                    SubscriptionStatus.active,
                    SubscriptionStatus.expired,
                  ])
                    AppButton(
                      label: 'home.${status.name}'.tr(),
                      intent: AppButtonIntent.secondary,
                      onPressed: () => session.setAuthenticated(
                        user: const User(
                          id: 'demo',
                          email: 'demo@example.invalid',
                          displayName: 'Demo',
                        ),
                        tokens: const TokenPair(
                          accessToken: 'development-only',
                          refreshToken: 'development-only',
                        ),
                        subscription: UserSubscription(
                          status: status,
                          source: 'development',
                        ),
                      ),
                    ),
                ],
              ),
              if (notifications != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PermissionExplanationCard(
                  title: 'notifications.title'.tr(),
                  body: 'notifications.explanation'.tr(),
                  actionLabel: 'notifications.allow'.tr(),
                  onAction: notifications!.requestPermission,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'notifications.send'.tr(),
                  onPressed: () => notifications!.show(
                    LocalNotificationRequest(
                      id: 1001,
                      title: 'notifications.test_title'.tr(),
                      body: 'notifications.test_body'.tr(),
                      payload: 'flutterstarter-dev:/settings',
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    ),
  );
  Widget _row(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(value),
  );

  String _subscriptionLabel(SubscriptionStatus status) => switch (status) {
    SubscriptionStatus.gracePeriod => 'home.subscription_status.grace_period',
    _ => 'home.subscription_status.${status.name}',
  };
}
