import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

/// Session token pair issued by the future MWB API.
class AuthTokens {
  const AuthTokens({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;
}

/// Abstraction over secure session-token storage.
///
/// Tokens never go to SharedPreferences. The production implementation uses
/// the iOS Keychain and Android Keystore-backed storage.
abstract interface class TokenStorage {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    try {
      final access = await _storage.read(key: StorageKeys.secureAccessToken);
      if (access == null || access.isEmpty) return null;
      final refresh = await _storage.read(key: StorageKeys.secureRefreshToken);
      return AuthTokens(accessToken: access, refreshToken: refresh);
    } catch (_) {
      // Keystore can be unavailable (e.g. after a device restore). Treat as signed out.
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: StorageKeys.secureAccessToken, value: tokens.accessToken);
    if (tokens.refreshToken != null) {
      await _storage.write(key: StorageKeys.secureRefreshToken, value: tokens.refreshToken);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: StorageKeys.secureAccessToken);
    await _storage.delete(key: StorageKeys.secureRefreshToken);
  }
}

class InMemoryTokenStorage implements TokenStorage {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
