import 'package:flutter/widgets.dart';

/// Small backend-free formatter for the locales shipped by the template.
/// Product applications with richer formatting needs should replace this
/// extension point with `intl` and generated locale data.
String formatLocalDateTime(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).languageCode;
  return formatLocalDateTimeForLocale(value, locale);
}

String formatLocalDateTimeForLocale(DateTime value, String languageCode) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  if (languageCode == 'ru') {
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year} ${local.hour}:$minute';
  }
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${local.month}/${local.day}/${local.year}, $hour:$minute $period';
}
