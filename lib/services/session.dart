import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'anon_session_token';
const _rememberEmailKey = 'anon_remember_email';

class SessionStore {
  SessionStore._();
  static final instance = SessionStore._();

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> getToken() => _secure.read(key: _tokenKey);

  Future<void> setToken(String? token, {required bool remember}) async {
    if (token == null || token.isEmpty) {
      await _secure.delete(key: _tokenKey);
      return;
    }
    await _secure.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() => _secure.delete(key: _tokenKey);

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberEmailKey);
  }

  Future<void> setRememberedEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await prefs.remove(_rememberEmailKey);
    } else {
      await prefs.setString(_rememberEmailKey, email.toLowerCase());
    }
  }
}
