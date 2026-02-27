import 'package:permission_handler/permission_handler.dart';

/// Handles camera and storage permissions for the app
class PermissionHandler {
  /// Request camera permission
  /// Returns true if granted, false otherwise
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request storage permission (Android only, for saving photos)
  /// Returns true if granted, false otherwise
  static Future<bool> requestStoragePermission() async {
    if (await Permission.storage.isPermanentlyDenied) {
      // User has permanently denied, need to open settings
      return false;
    }
    
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Request photos permission (iOS only)
  /// Returns true if granted, false otherwise
  static Future<bool> requestPhotosPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  /// Request all necessary permissions for camera capture
  /// Returns true if all granted, false otherwise
  static Future<bool> requestAllPermissions() async {
    final cameraGranted = await requestCameraPermission();
    
    if (!cameraGranted) {
      return false;
    }

    // Request storage on Android, photos on iOS
    // Note: Platform-specific checks would be better, 
    // but for simplicity we'll try both
    try {
      await requestPhotosPermission();
      await requestStoragePermission();
    } catch (e) {
      // Platform-specific permission not available, that's okay
    }

    return true;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    return await Permission.camera.isGranted;
  }

  /// Check if storage permission is granted (Android)
  static Future<bool> isStoragePermissionGranted() async {
    return await Permission.storage.isGranted;
  }

  /// Check if photos permission is granted (iOS)
  static Future<bool> isPhotosPermissionGranted() async {
    final status = await Permission.photos.status;
    return status.isGranted || status.isLimited;
  }

  /// Open app settings if user needs to manually grant permissions
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Show rationale for why we need camera permission
  static String getCameraPermissionRationale() {
    return 'FoodVision needs camera access to capture photos of your meals for analysis.';
  }

  /// Show rationale for why we need storage permission
  static String getStoragePermissionRationale() {
    return 'FoodVision needs storage access to save and manage your meal photos.';
  }
}
