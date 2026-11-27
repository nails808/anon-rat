import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions for remaining agent features (no phone/call access).
Future<Map<Permission, PermissionStatus>> requestAgentPermissions() async {
  return [
    Permission.locationWhenInUse,
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
  ].request();
}

Future<void> openAppPermissionSettings() => openAppSettings();
