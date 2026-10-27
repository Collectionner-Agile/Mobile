import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT and the cached profile in the platform keystore
/// (Android Keystore / iOS Keychain). Never in SharedPreferences.
class SecureSessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  static const _tokenKey = 'session.token';
  static const _userKey = 'session.user';

  final FlutterSecureStorage _storage;

  Future<({String token, Map<String, dynamic>? user})?> read() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return null;
    final rawUser = await _storage.read(key: _userKey);
    Map<String, dynamic>? user;
    if (rawUser != null) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map<String, dynamic>) user = decoded;
      } on FormatException {
        user = null;
      }
    }
    return (token: token, user: user);
  }

  Future<void> write(String token, Map<String, dynamic> user) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
