import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The sign-in tokens. Kept in the phone's secure storage (Android Keystore / iOS Keychain), never in plain preferences.
class Tokens {
  const Tokens({required this.access, required this.refresh});
  final String access;
  final String refresh;

  static Tokens? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['access_token'] == null || json['refresh_token'] == null) return null;
    return Tokens(access: json['access_token'] as String, refresh: json['refresh_token'] as String);
  }
}

abstract class TokenStore {
  Future<Tokens?> read();
  Future<void> write(Tokens tokens);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final FlutterSecureStorage _storage;
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';

  @override
  Future<Tokens?> read() async {
    final access = await _storage.read(key: _access);
    final refresh = await _storage.read(key: _refresh);
    if (access == null || refresh == null) return null;
    return Tokens(access: access, refresh: refresh);
  }

  @override
  Future<void> write(Tokens tokens) async {
    await _storage.write(key: _access, value: tokens.access);
    await _storage.write(key: _refresh, value: tokens.refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}

/// For tests.
class MemoryTokenStore implements TokenStore {
  Tokens? tokens;
  @override
  Future<Tokens?> read() async => tokens;
  @override
  Future<void> write(Tokens t) async => tokens = t;
  @override
  Future<void> clear() async => tokens = null;
}
