import 'dart:convert';

/// Reads the `exp` claim without verifying the signature; the backend remains
/// the authority. Used only to drop sessions that are already expired locally.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;
    final exp = decoded['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } on FormatException {
    return null;
  }
}

bool isJwtExpired(String token, {DateTime? now}) {
  final expiry = jwtExpiry(token);
  if (expiry == null) return true;
  return !expiry.isAfter((now ?? DateTime.now()).toUtc().add(const Duration(seconds: 30)));
}
