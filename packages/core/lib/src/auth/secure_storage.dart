import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session.dart';

abstract class SessionStorage {
  Future<void> saveSession(Session session);
  Future<Session?> getSession();
  Future<void> clearSession();

  Future<void> saveTokens({required String accessToken, required String refreshToken, required DateTime expiresAt});
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();

  Future<void> saveHouseholdKey(String keyHex);
  Future<String?> getHouseholdKey();
}

class SecureSessionStorage implements SessionStorage {
  final FlutterSecureStorage _storage;

  static const String _keySession = 'weired_session';
  static const String _keyAccessToken = 'weired_access_token';
  static const String _keyRefreshToken = 'weired_refresh_token';
  static const String _keyHouseholdKey = 'weired_household_key';

  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  @override
  Future<void> saveSession(Session session) async {
    final raw = jsonEncode(session.toJson());
    await _storage.write(key: _keySession, value: raw);
    await _storage.write(key: _keyAccessToken, value: session.accessToken);
    await _storage.write(key: _keyRefreshToken, value: session.refreshToken);
    if (session.householdKey != null) {
      await _storage.write(key: _keyHouseholdKey, value: session.householdKey);
    }
  }

  @override
  Future<Session?> getSession() async {
    final raw = await _storage.read(key: _keySession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Session.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    await _storage.delete(key: _keySession);
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyHouseholdKey);
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);

    final current = await getSession();
    if (current != null) {
      final updated = current.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );
      await _storage.write(key: _keySession, value: jsonEncode(updated.toJson()));
    }
  }

  @override
  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  @override
  Future<void> saveHouseholdKey(String keyHex) => _storage.write(key: _keyHouseholdKey, value: keyHex);

  @override
  Future<String?> getHouseholdKey() => _storage.read(key: _keyHouseholdKey);
}

class MemorySessionStorage implements SessionStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> saveSession(Session session) async {
    _data['session'] = jsonEncode(session.toJson());
    _data['access_token'] = session.accessToken;
    _data['refresh_token'] = session.refreshToken;
    if (session.householdKey != null) {
      _data['household_key'] = session.householdKey!;
    }
  }

  @override
  Future<Session?> getSession() async {
    final raw = _data['session'];
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    _data.clear();
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    _data['access_token'] = accessToken;
    _data['refresh_token'] = refreshToken;
    final current = await getSession();
    if (current != null) {
      final updated = current.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );
      _data['session'] = jsonEncode(updated.toJson());
    }
  }

  @override
  Future<String?> getAccessToken() async => _data['access_token'];

  @override
  Future<String?> getRefreshToken() async => _data['refresh_token'];

  @override
  Future<void> saveHouseholdKey(String keyHex) async => _data['household_key'] = keyHex;

  @override
  Future<String?> getHouseholdKey() async => _data['household_key'];
}
