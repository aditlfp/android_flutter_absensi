import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    return await _requestPermission(Permission.camera);
  }

  static Future<bool> requestLocationPermission() async {
    return await _requestPermission(Permission.location);
  }

  static Future<Map<Permission, bool>> requestAll() async {
    final permissions = [Permission.camera, Permission.location];
    final statuses = await permissions.request();

    return {
      for (var p in permissions) p: statuses[p]?.isGranted ?? false,
    };
  }

  static Future<void> handlePermission(
    BuildContext context,
    Permission permission, {
    String? title,
    String? message,
  }) async {
    final status = await permission.status;
    if (status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title ?? 'Permission Required'),
          content: Text(message ?? 'This feature requires ${permission.toString().split('.').last} permission. Please grant it in the app settings.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } else if (status.isDenied) {
      await permission.request();
    }
  }
}
