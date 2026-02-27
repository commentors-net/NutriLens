import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'capture_controller.dart';
import 'review_screen.dart';
import '../../core/utils/permission_handler.dart' as app_permissions;

/// Camera capture screen for taking multiple photos of a meal
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraController? _cameraController;
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    // Check permissions
    final hasPermission = await ref.read(captureProvider.notifier).hasPermissions();
    
    if (!hasPermission) {
      final granted = await ref.read(captureProvider.notifier).requestPermissions();
      if (!granted) {
        setState(() {
          _error = 'Camera permission required';
          _isInitializing = false;
        });
        return;
      }
    }

    // Get available cameras
    final cameras = await ref.read(availableCamerasProvider.future);
    
    if (cameras.isEmpty) {
      setState(() {
        _error = 'No camera available';
        _isInitializing = false;
      });
      return;
    }

    // Initialize camera (use back camera)
    final camera = cameras.first;
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize camera: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    await ref.read(captureProvider.notifier).capturePhoto(_cameraController!);
    
    // Show feedback
    final state = ref.read(captureProvider);
    if (state.error != null) {
      _showSnackBar(state.error!);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _navigateToReview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReviewScreen(),
      ),
    );
  }

  void _openSettings() async {
    await app_permissions.PermissionHandler.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(captureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Meal Photos'),
        actions: [
          if (captureState.photoCount > 0)
            TextButton(
              onPressed: _navigateToReview,
              child: Text(
                'Review (${captureState.photoCount})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _buildBody(context, captureState),
    );
  }

  Widget _buildBody(BuildContext context, captureState) {
    if (_error != null) {
      return _buildErrorView();
    }

    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: Text('Camera not available'),
      );
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),

        // Guidance overlay
        _buildGuidanceOverlay(captureState),

        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildControls(captureState),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (_error!.contains('permission'))
              ElevatedButton(
                onPressed: _openSettings,
                child: const Text('Open Settings'),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceOverlay(captureState) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            // Photo counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: captureState.hasMinPhotos
                    ? Colors.green.withOpacity(0.9)
                    : Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Photos: ${captureState.photoCount} / ${captureState.minPhotos}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Guidance text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                captureState.suggestedNextShot,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(captureState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Review button
          if (captureState.photoCount > 0)
            _buildControlButton(
              icon: Icons.photo_library,
              label: 'Review',
              onTap: _navigateToReview,
            )
          else
            const SizedBox(width: 80),

          // Capture button
          GestureDetector(
            onTap: captureState.isCapturing || captureState.hasMaxPhotos
                ? null
                : _capturePhoto,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: captureState.hasMaxPhotos
                    ? Colors.grey
                    : Colors.white,
                border: Border.all(
                  color: captureState.hasMinPhotos
                      ? Colors.green
                      : Colors.orange,
                  width: 4,
                ),
              ),
              child: captureState.isCapturing
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Icon(
                      Icons.camera_alt,
                      size: 40,
                      color: captureState.hasMaxPhotos
                          ? Colors.white
                          : Colors.black,
                    ),
            ),
          ),

          // Delete last button
          if (captureState.photoCount > 0)
            _buildControlButton(
              icon: Icons.delete,
              label: 'Delete',
              onTap: () {
                ref.read(captureProvider.notifier).removeLastPhoto();
                _showSnackBar('Last photo removed');
              },
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.3),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
