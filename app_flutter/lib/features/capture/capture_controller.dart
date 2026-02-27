import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'capture_state.dart';
import '../../core/utils/permission_handler.dart' as app_permissions;

/// Notifier for capture state
class CaptureNotifier extends StateNotifier<CaptureState> {
  CaptureNotifier() : super(const CaptureState());

  /// Add a captured photo
  void addPhoto(String path) {
    state = state.addPhoto(path);
  }

  /// Remove the last photo
  void removeLastPhoto() {
    state = state.removeLastPhoto();
  }

  /// Remove a specific photo
  void removePhotoAt(int index) {
    state = state.removePhotoAt(index);
  }

  /// Clear all photos
  void clear() {
    state = state.clear();
  }

  /// Set capturing state
  void setCapturing(bool capturing) {
    state = state.setCapturing(capturing);
  }

  /// Set error
  void setError(String error) {
    state = state.setError(error);
  }

  /// Capture a photo using the camera controller
  Future<void> capturePhoto(CameraController cameraController) async {
    if (state.hasMaxPhotos) {
      setError('Maximum ${state.maxPhotos} photos reached');
      return;
    }

    if (!cameraController.value.isInitialized) {
      setError('Camera not initialized');
      return;
    }

    try {
      setCapturing(true);

      // Capture the image
      final XFile image = await cameraController.takePicture();

      // Save to app directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'meal_photo_$timestamp.jpg';
      final savePath = '${directory.path}/$fileName';

      // Copy file to permanent location
      await File(image.path).copy(savePath);

      // Add to state
      addPhoto(savePath);

      setCapturing(false);
    } catch (e) {
      setCapturing(false);
      setError('Failed to capture photo: $e');
    }
  }

  /// Request camera permissions
  Future<bool> requestPermissions() async {
    return await app_permissions.PermissionHandler.requestAllPermissions();
  }

  /// Check if camera permission is granted
  Future<bool> hasPermissions() async {
    return await app_permissions.PermissionHandler.isCameraPermissionGranted();
  }
}

/// Provider for capture state
final captureProvider = StateNotifierProvider<CaptureNotifier, CaptureState>(
  (ref) => CaptureNotifier(),
);

/// Provider for available cameras
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  try {
    return await availableCameras();
  } catch (e) {
    return [];
  }
});
