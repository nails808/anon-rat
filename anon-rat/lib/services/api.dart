import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';

const String kDefaultApiBase = 'https://anon-push-api.bittermusic.workers.dev';

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class AnonUser {
  AnonUser({required this.id, required this.email, this.status = 'active'});
  final dynamic id;
  final String email;
  final String status;
  factory AnonUser.fromJson(Map<String, dynamic> j) => AnonUser(
        id: j['id'],
        email: (j['email'] ?? '').toString(),
        status: (j['status'] ?? 'active').toString(),
      );
}

class ApiService {
  ApiService({String? base})
      : baseUrl = (base ??
                const String.fromEnvironment('API_BASE', defaultValue: kDefaultApiBase))
            .replaceAll(RegExp(r'/$'), '');

  final String baseUrl;
  final _session = SessionStore.instance;

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _session.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    final uri = Uri.parse('$baseUrl$path');
    late http.Response res;
    try {
      res = method == 'POST'
          ? await http.post(uri, headers: headers, body: jsonEncode(body ?? {}))
          : await http.get(uri, headers: headers);
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection.');
    }
    Map<String, dynamic> data = {};
    try {
      final d = jsonDecode(res.body);
      if (d is Map<String, dynamic>) data = d;
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        (data['error'] as String?) ?? 'Request failed (${res.statusCode})',
        status: res.statusCode,
      );
    }
    return data;
  }

  Future<AnonUser> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final data = await _request('/api/login', method: 'POST', body: {
      'email': email.trim(),
      'password': password,
      'remember': remember,
    });
    final token = (data['token'] ?? '').toString();
    final user = AnonUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    await _session.setToken(token, remember: remember);
    await _session.setRememberedEmail(remember ? email.trim() : null);
    return user;
  }

  Future<AnonUser> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required bool remember,
  }) async {
    final data = await _request('/api/register', method: 'POST', body: {
      'email': email.trim(),
      'password': password,
      'passwordConfirm': passwordConfirm,
      'remember': remember,
    });
    final token = (data['token'] ?? '').toString();
    final user = AnonUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    await _session.setToken(token, remember: remember);
    await _session.setRememberedEmail(remember ? email.trim() : null);
    return user;
  }

  Future<AnonUser> me() async {
    final data = await _request('/api/me', auth: true);
    final userMap = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : data;
    return AnonUser.fromJson(userMap);
  }

  Future<void> logout() async {
    try {
      await _request('/api/logout', method: 'POST', auth: true);
    } catch (_) {}
    await _session.clearToken();
  }

  String friendlyError(Object err) {
    if (err is! ApiException) return 'Something went wrong. Please try again.';
    final msg = err.message.toLowerCase();
    if (err.status == 429) return 'Too many attempts. Please wait a few minutes and try again.';
    if (msg.contains('already exists')) return 'That email is already registered. Try logging in instead.';
    if (msg.contains('invalid email or password')) return 'Email or password is incorrect.';
    if (msg.contains('not available')) return 'This account is not available.';
    if (msg.contains('reach the server')) return 'Could not reach the server. Check your connection.';
    return err.message;
  }
}
