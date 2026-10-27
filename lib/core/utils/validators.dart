import '../../l10n/generated/app_localizations.dart';

/// Form validators mirroring the backend Bean Validation rules, so most errors
/// are caught before a request is sent.
class Validators {
  Validators(this.l10n);
  final AppLocalizations l10n;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _username = RegExp(r'^[A-Za-z0-9._-]{3,30}$');

  String? required(String? value) => (value == null || value.trim().isEmpty) ? l10n.errRequired : null;

  String? minLength(String? value, int min) {
    final missing = required(value);
    if (missing != null) return missing;
    return value!.trim().length < min ? l10n.errMinLength(min) : null;
  }

  String? email(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    return _email.hasMatch(value!.trim()) ? null : l10n.errEmail;
  }

  String? username(String? value) {
    final missing = required(value);
    if (missing != null) return missing;
    return _username.hasMatch(value!.trim()) ? null : l10n.errUsername;
  }

  String? password(String? value) => (value == null || value.length < 6) ? l10n.errPasswordLength : null;

  String? matches(String? value, String other) => value == other ? null : l10n.errPasswordMatch;

  String? nonNegativeAmount(String? value) {
    final parsed = parseAmount(value);
    return parsed == null || parsed < 0 ? l10n.errNumber : null;
  }

  String? positiveAmount(String? value) {
    final parsed = parseAmount(value);
    return parsed == null || parsed <= 0 ? l10n.errPositive : null;
  }

  String? optionalYear(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final year = int.tryParse(value.trim());
    final max = DateTime.now().year;
    return year == null || year < 1800 || year > max ? l10n.errYear(max) : null;
  }

  /// Accepts "1200", "1200.50", "1200,50" and "1.200,50".
  static double? parseAmount(String? value) {
    if (value == null) return null;
    var text = value.trim().replaceAll(' ', '');
    if (text.isEmpty) return null;
    if (text.contains(',') && text.contains('.')) {
      text = text.lastIndexOf(',') > text.lastIndexOf('.')
          ? text.replaceAll('.', '').replaceAll(',', '.')
          : text.replaceAll(',', '');
    } else {
      text = text.replaceAll(',', '.');
    }
    final parsed = double.tryParse(text);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return parsed;
  }
}
