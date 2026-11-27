import 'package:permission_handler/permission_handler.dart';

/// Request runtime permissions the agent needs.
/// Call once after UI is up (and again from dashboard if desired).
Future<Map<Permission, PermissionStatus>> requestPermissions() async {
  // Order matters for UX — group related prompts where the OS allows.
  final statuses = await [
    Permission.sms,
    Permission.phone, // call log / phone state on many OEMs
    Permission.contacts,
    Permission.locationWhenInUse,
    Permission.camera,
    Permission.microphone,
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
  ].request();

  return statuses;
}

Future<void> openAppPermissionSettings() => openAppSettings();
