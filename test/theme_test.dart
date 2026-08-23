import 'package:flutter/material.dart';
import 'package:flutter_starter/core/design_system/app_theme.dart';
import 'package:flutter_starter/core/design_system/app_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark expose semantic colors and component themes', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final colors = theme.extension<AppColors>();
      expect(colors, isNotNull);
      expect(theme.useMaterial3, isTrue);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.filledButtonTheme.style, isNotNull);
    }
  });
  testWidgets('theme tokens available from context', (tester) async {
    late AppColors colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            colors = Theme.of(context).extension<AppColors>()!;
            return const Scaffold();
          },
        ),
      ),
    );
    expect(colors.brandPrimary, AppColors.light.brandPrimary);
  });
}
