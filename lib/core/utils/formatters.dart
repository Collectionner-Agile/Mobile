import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../network/api_exception.dart';

/// Collectioneer prices are in Peruvian soles (the web shows "S/ 1,200.00").
String formatMoney(num amount, String languageCode) {
  final format = NumberFormat.currency(
    locale: languageCode == 'en' ? 'en_US' : 'es_PE',
    symbol: 'S/ ',
    decimalDigits: amount % 1 == 0 ? 0 : 2,
  );
  return format.format(amount);
}

String formatDate(DateTime date, String languageCode) =>
    DateFormat.yMMMd(languageCode == 'en' ? 'en_US' : 'es_PE').format(date);

String formatDateTime(DateTime date, String languageCode) =>
    DateFormat.yMMMd(languageCode == 'en' ? 'en_US' : 'es_PE').add_Hm().format(date);

/// Compact remaining time, e.g. "2 d 4 h", "3 h 12 min", "45 s".
String formatRemaining(Duration remaining) {
  if (remaining.isNegative) return '0 s';
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  final seconds = remaining.inSeconds % 60;
  if (days > 0) return '$days d $hours h';
  if (hours > 0) return '$hours h $minutes min';
  if (minutes > 0) return '$minutes min $seconds s';
  return '$seconds s';
}

String describeError(Object error, AppLocalizations l10n) {
  if (error is! ApiException) return l10n.errorUnknown;
  if (error.hasUserFacingDetail && error.kind != ApiErrorKind.unavailable) return error.detail!;
  return switch (error.kind) {
    ApiErrorKind.network => l10n.errorNetwork,
    ApiErrorKind.timeout => l10n.errorTimeout,
    ApiErrorKind.unauthorized => l10n.errorUnauthorized,
    ApiErrorKind.forbidden => l10n.errorForbidden,
    ApiErrorKind.notFound => l10n.errorNotFound,
    ApiErrorKind.validation => l10n.errorValidation,
    ApiErrorKind.conflict => l10n.errorConflict,
    ApiErrorKind.tooLarge => l10n.errorTooLarge,
    ApiErrorKind.unsupportedMedia => l10n.errorUnsupportedMedia,
    ApiErrorKind.rateLimited => l10n.errorRateLimited,
    ApiErrorKind.unavailable => error.errorCode == 'AI_NOT_CONFIGURED' ? l10n.scanUnavailable : l10n.errorUnavailable,
    ApiErrorKind.server => l10n.errorServer,
    ApiErrorKind.invalidResponse => l10n.errorInvalidResponse,
    ApiErrorKind.cancelled => l10n.errorUnknown,
  };
}
