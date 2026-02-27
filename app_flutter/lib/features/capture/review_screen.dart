import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'capture_controller.dart';

/// Review screen for viewing and managing captured photos before analysis
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captureState = ref.watch(captureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Photos'),
        actions: [
          if (captureState.hasMinPhotos)
            TextButton(
              onPressed: () {
                // TODO: Navigate to analysis or call analyze API
                _showAnalyzeDialog(context);
              },
              child: const Text(
                'Analyze',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _buildBody(context, ref, captureState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, captureState) {
    if (captureState.photoCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_camera, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No photos captured yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photos'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Status banner
        _buildStatusBanner(captureState),

        // Photo grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: captureState.photoCount,
            itemBuilder: (context, index) {
              return _buildPhotoTile(
                context,
                ref,
                captureState.photoPaths[index],
                index,
              );
            },
          ),
        ),

        // Bottom actions
        _buildBottomActions(context, ref, captureState),
      ],
    );
  }

  Widget _buildStatusBanner(captureState) {
    final hasMin = captureState.hasMinPhotos;
    final hasMax = captureState.hasMaxPhotos;

    String message;
    Color color;
    IconData icon;

    if (hasMax) {
      message = 'Maximum photos reached (${captureState.maxPhotos})';
      color = Colors.blue;
      icon = Icons.check_circle;
    } else if (hasMin) {
      message = 'Ready to analyze (${captureState.photoCount}/${captureState.maxPhotos} photos)';
      color = Colors.green;
      icon = Icons.check_circle;
    } else {
      final remaining = captureState.minPhotos - captureState.photoCount;
      message = 'Take $remaining more photo${remaining > 1 ? 's' : ''} (minimum ${captureState.minPhotos})';
      color = Colors.orange;
      icon = Icons.info;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: color.withOpacity(0.1),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile(
    BuildContext context,
    WidgetRef ref,
    String photoPath,
    int index,
  ) {
    return Stack(
      children: [
        // Photo image
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(photoPath),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Photo number badge
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Delete button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              _confirmDelete(context, ref, index);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, WidgetRef ref, captureState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Add more photos button
          if (!captureState.hasMaxPhotos)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Add More'),
              ),
            ),

          if (!captureState.hasMaxPhotos && captureState.hasMinPhotos)
            const SizedBox(width: 12),

          // Analyze button
          if (captureState.hasMinPhotos)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Navigate to analysis or call analyze API
                  _showAnalyzeDialog(context);
                },
                icon: const Icon(Icons.analytics),
                label: const Text('Analyze Meal'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(captureProvider.notifier).removePhotoAt(index);
              Navigator.of(context).pop();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo deleted')),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAnalyzeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analyze Meal'),
        content: const Text(
          'This feature will be implemented in Milestone 2.\n\n'
          'It will send photos to the backend API and display nutrition results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
