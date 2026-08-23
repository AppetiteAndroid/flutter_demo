import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../extensions/build_context_extensions.dart';
import 'app_tokens.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(child: body),
  );
}

enum AppButtonIntent { primary, secondary, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.intent = AppButtonIntent.primary,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final AppButtonIntent intent;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox.square(
            dimension: AppIconSize.medium,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.textInverse,
            ),
          )
        : Text(label);
    final callback = loading ? null : onPressed;
    final button = switch (intent) {
      AppButtonIntent.primary => FilledButton(
        onPressed: callback,
        child: child,
      ),
      AppButtonIntent.secondary => OutlinedButton(
        onPressed: callback,
        child: child,
      ),
      AppButtonIntent.destructive => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: context.colors.error),
        onPressed: callback,
        child: child,
      ),
    };
    return loading
        ? Semantics(
            label: '$label, ${'common.loading'.tr()}',
            button: true,
            enabled: false,
            excludeSemantics: true,
            child: button,
          )
        : button;
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.errorText,
    this.semanticLabel,
    this.obscureText = false,
    this.enabled = true,
  });
  final TextEditingController? controller;
  final String? hintText, errorText, semanticLabel;
  final ValueChanged<String>? onChanged;
  final bool obscureText, enabled;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? hintText,
    textField: true,
    enabled: enabled,
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      obscureText: obscureText,
      enabled: enabled,
      decoration: InputDecoration(hintText: hintText, errorText: errorText),
    ),
  );
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'common.loading'.tr(),
      child: const CircularProgressIndicator(),
    ),
  );
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: context.colors.error,
            size: AppIconSize.large,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'common.try_again'.tr(),
              onPressed: onRetry,
              intent: AppButtonIntent.secondary,
            ),
          ],
        ],
      ),
    ),
  );
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: context.textStyles.bodyLarge,
      ),
    ),
  );
}

abstract final class AppSnackBar {
  static void show(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class AppSelectionTile<T> extends StatelessWidget {
  const AppSelectionTile({
    super.key,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  final String title;
  final T value, groupValue;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Semantics(
      selected: selected,
      button: true,
      child: ListTile(
        minTileHeight: 48,
        title: Text(title),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
        ),
        onTap: () => onChanged(value),
      ),
    );
  }
}

abstract final class AppDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    List<Widget> actions = const [],
  }) => showDialog<T>(
    context: context,
    builder: (_) =>
        AlertDialog(title: Text(title), content: content, actions: actions),
  );
}

abstract final class AppBottomSheet {
  static Future<T?> show<T>(BuildContext context, {required Widget child}) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      );
}

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});
  @override
  Widget build(BuildContext context) => const Divider();
}

class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) =>
      SwitchListTile(title: Text(label), value: value, onChanged: onChanged);
}

class AppImage extends StatelessWidget {
  const AppImage.network(
    this.source, {
    super.key,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  }) : asset = false;
  const AppImage.asset(
    this.source, {
    super.key,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  }) : asset = true;
  final String source;
  final bool asset;
  final BoxFit fit;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => asset
      ? Image.asset(
          source,
          fit: fit,
          semanticLabel: semanticLabel,
          excludeFromSemantics: semanticLabel == null,
          errorBuilder: (_, _, _) =>
              Icon(Icons.broken_image, color: context.colors.iconDisabled),
        )
      : Image.network(
          source,
          fit: fit,
          semanticLabel: semanticLabel,
          excludeFromSemantics: semanticLabel == null,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : const AppSkeleton(),
          errorBuilder: (_, _, _) =>
              Icon(Icons.broken_image, color: context.colors.iconDisabled),
        );
}

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.height = 48});
  final double height;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: 'common.loading'.tr(),
      child: AnimatedOpacity(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 500),
        opacity: .7,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: context.colors.stateDisabled,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

class AppRefresh extends StatelessWidget {
  const AppRefresh({super.key, required this.onRefresh, required this.child});
  final RefreshCallback onRefresh;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      RefreshIndicator(onRefresh: onRefresh, child: child);
}

enum PaginationFooterState { hidden, loading, error, end }

class AppPaginationFooter extends StatelessWidget {
  const AppPaginationFooter({super.key, required this.state, this.onRetry});
  final PaginationFooterState state;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => switch (state) {
    PaginationFooterState.hidden => const SizedBox.shrink(),
    PaginationFooterState.loading => const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: AppLoader(),
    ),
    PaginationFooterState.error => Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: AppButton(
        label: 'common.try_again'.tr(),
        onPressed: onRetry,
        intent: AppButtonIntent.secondary,
      ),
    ),
    PaginationFooterState.end => const SizedBox(height: AppSpacing.md),
  };
}

class PermissionExplanationCard extends StatelessWidget {
  const PermissionExplanationCard({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });
  final String title, body, actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(body),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    ),
  );
}

class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({
    super.key,
    required this.label,
    required this.visible,
  });
  final String label;
  final bool visible;
  @override
  Widget build(BuildContext context) => visible
      ? Semantics(
          label: label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.warning,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              child: Text(
                label,
                style: context.textStyles.labelSmall?.copyWith(
                  color: context.colors.textInverse,
                ),
              ),
            ),
          ),
        )
      : const SizedBox.shrink();
}
