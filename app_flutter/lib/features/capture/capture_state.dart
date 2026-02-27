import 'package:flutter/foundation.dart';

/// State model for the capture flow
/// Tracks captured photo paths and capture progress
class CaptureState {
  final List<String> photoPaths;
  final int minPhotos;
  final int maxPhotos;
  final bool isCapturing;
  final String? error;

  const CaptureState({
    this.photoPaths = const [],
    this.minPhotos = 3,
    this.maxPhotos = 8,
    this.isCapturing = false,
    this.error,
  });

  /// Number of photos captured
  int get photoCount => photoPaths.length;

  /// Whether minimum photos requirement is met
  bool get hasMinPhotos => photoCount >= minPhotos;

  /// Whether maximum photos limit is reached
  bool get hasMaxPhotos => photoCount >= maxPhotos;

  /// Whether can add more photos
  bool get canAddMore => photoCount < maxPhotos;

  /// Get suggested next shot based on current count
  String get suggestedNextShot {
    switch (photoCount) {
      case 0:
        return 'Take a top-down photo of your meal';
      case 1:
        return 'Take a photo from the left side';
      case 2:
        return 'Take a photo from the right side';
      case 3:
        return 'Take a closeup of interesting items';
      default:
        return 'Take another angle for better accuracy';
    }
  }

  /// Copy with method for immutable updates
  CaptureState copyWith({
    List<String>? photoPaths,
    int? minPhotos,
    int? maxPhotos,
    bool? isCapturing,
    String? error,
  }) {
    return CaptureState(
      photoPaths: photoPaths ?? this.photoPaths,
      minPhotos: minPhotos ?? this.minPhotos,
      maxPhotos: maxPhotos ?? this.maxPhotos,
      isCapturing: isCapturing ?? this.isCapturing,
      error: error,
    );
  }

  /// Add a photo path
  CaptureState addPhoto(String path) {
    if (hasMaxPhotos) {
      return copyWith(error: 'Maximum $maxPhotos photos reached');
    }
    return copyWith(
      photoPaths: [...photoPaths, path],
      error: null,
    );
  }

  /// Remove the last photo
  CaptureState removeLastPhoto() {
    if (photoPaths.isEmpty) {
      return this;
    }
    final newPaths = [...photoPaths];
    newPaths.removeLast();
    return copyWith(photoPaths: newPaths, error: null);
  }

  /// Remove a specific photo by index
  CaptureState removePhotoAt(int index) {
    if (index < 0 || index >= photoPaths.length) {
      return this;
    }
    final newPaths = [...photoPaths];
    newPaths.removeAt(index);
    return copyWith(photoPaths: newPaths, error: null);
  }

  /// Clear all photos
  CaptureState clear() {
    return copyWith(photoPaths: [], error: null);
  }

  /// Set capturing state
  CaptureState setCapturing(bool capturing) {
    return copyWith(isCapturing: capturing);
  }

  /// Set error message
  CaptureState setError(String error) {
    return copyWith(error: error);
  }

  @override
  String toString() {
    return 'CaptureState(photoCount: $photoCount, hasMinPhotos: $hasMinPhotos, isCapturing: $isCapturing, error: $error)';
  }
}
