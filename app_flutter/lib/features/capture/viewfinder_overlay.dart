import 'package:flutter/material.dart';

enum CaptureAngle {
  topDown,
  angle45,
  sideCloseup,
}

class ViewfinderOverlay extends StatelessWidget {
  final int photoCount;
  final int minPhotos;
  final String? customGuidance;

  const ViewfinderOverlay({
    super.key,
    required this.photoCount,
    this.minPhotos = 3,
    this.customGuidance,
  });

  CaptureAngle get currentAngle {
    if (photoCount == 0) return CaptureAngle.topDown;
    if (photoCount == 1) return CaptureAngle.angle45;
    return CaptureAngle.sideCloseup;
  }

  String get angleTitle {
    switch (currentAngle) {
      case CaptureAngle.topDown:
        return 'Shot 1: Top-Down (90°)';
      case CaptureAngle.angle45:
        return 'Shot 2: Angled (45°)';
      case CaptureAngle.sideCloseup:
        return 'Shot 3+: Side / Closeup';
    }
  }

  String get angleInstruction {
    if (customGuidance != null && customGuidance!.isNotEmpty) {
      return customGuidance!;
    }
    switch (currentAngle) {
      case CaptureAngle.topDown:
        return 'Hold phone directly over food to capture full plate boundaries';
      case CaptureAngle.angle45:
        return 'Tilt phone at 45° to reveal food height and volume';
      case CaptureAngle.sideCloseup:
        return 'Get closer to capture texture, density & layered ingredients';
    }
  }

  IconData get angleIcon {
    switch (currentAngle) {
      case CaptureAngle.topDown:
        return Icons.crop_free;
      case CaptureAngle.angle45:
        return Icons.change_circle_outlined;
      case CaptureAngle.sideCloseup:
        return Icons.zoom_in;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Corner-bracketed framing box in the center
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.78,
              height: MediaQuery.of(context).size.width * 0.78,
              child: CustomPaint(
                painter: _ViewfinderReticlePainter(
                  color: photoCount >= minPhotos
                      ? Colors.greenAccent
                      : Colors.white.withValues(alpha: 0.85),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      angleIcon,
                      size: 38,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top floating instruction card
          Positioned(
            top: 68,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step indicator row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StepBadge(
                        step: 1,
                        label: 'Top-Down',
                        isCompleted: photoCount > 0,
                        isActive: photoCount == 0,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios,
                          size: 10, color: Colors.grey),
                      const SizedBox(width: 8),
                      _StepBadge(
                        step: 2,
                        label: '45° Angle',
                        isCompleted: photoCount > 1,
                        isActive: photoCount == 1,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios,
                          size: 10, color: Colors.grey),
                      const SizedBox(width: 8),
                      _StepBadge(
                        step: 3,
                        label: 'Closeup',
                        isCompleted: photoCount >= 3,
                        isActive: photoCount >= 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    angleTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    angleInstruction,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final int step;
  final String label;
  final bool isCompleted;
  final bool isActive;

  const _StepBadge({
    required this.step,
    required this.label,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white.withValues(alpha: 0.15);
    Color textColor = Colors.white70;

    if (isCompleted) {
      bg = Colors.green.withValues(alpha: 0.8);
      textColor = Colors.white;
    } else if (isActive) {
      bg = Colors.deepOrange.withValues(alpha: 0.9);
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCompleted)
            const Icon(Icons.check, size: 12, color: Colors.white)
          else
            Text(
              '$step',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderReticlePainter extends CustomPainter {
  final Color color;

  _ViewfinderReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;

    // Top-Left corner
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right corner
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-Left corner
    canvas.drawLine(
        Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-Right corner
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderReticlePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
