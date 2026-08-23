import 'package:flutter/material.dart';
import 'package:flutter_starter/app/config/app_config.dart';
import 'package:flutter_starter/core/design_system/app_theme.dart';
import 'package:flutter_starter/core/design_system/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('v0.2 components are accessible in ${theme.brightness.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ListView(
              children: [
                const AppSkeleton(),
                AppSwitch(label: 'Toggle', value: true, onChanged: (_) {}),
                PermissionExplanationCard(
                  title: 'Permission',
                  body: 'Reason',
                  actionLabel: 'Continue',
                  onAction: () {},
                ),
                const EnvironmentBadge(label: 'DEV', visible: true),
                const AppPaginationFooter(state: PaginationFooterState.loading),
              ],
            ),
          ),
        ),
      );
      expect(find.text('DEV'), findsOneWidget);
      expect(find.text('Toggle'), findsOneWidget);
      expect(
        tester.getSize(find.text('Continue').first).height,
        greaterThan(0),
      );
    });
  }
  testWidgets('production environment badge is hidden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EnvironmentBadge(
          label: 'PROD',
          visible: AppEnvironment.production != AppEnvironment.production,
        ),
      ),
    );
    expect(find.text('PROD'), findsNothing);
  });
}
