import 'package:permission_handler/permission_handler.dart';

/// Request runtime permissions still required by remaining agent commands.
Future<Map<Permission, PermissionStatus>> requestAgentPermissions() async {
  return [
    Permission.locationWhenInUse,
    Permission.phone, // SIM / line status on many OEMs
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
  ].request();
}

Future<void> openAppPermissionSettings() => openAppSettings();
