import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Ultra-smooth 60 FPS deviation gauge with hardware-accelerated bar painting.
class SignalGauge extends StatelessWidget {
  final double deviation; // Degrees (-180 to +180)
  final double alignedTolerance; // e.g. 3.0°
  final double warningTolerance; // e.g. 10.0°

  const SignalGauge({
    super.key,
    required this.deviation,
    this.alignedTolerance = 3.0,
    this.warningTolerance = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final double absDev = deviation.abs();
    final bool isAligned = absDev <= alignedTolerance;
    final bool isClose = absDev <= warningTolerance;

    final Color statusColor = isAligned
        ? AppColors.alignedGreen
        : isClose
            ? AppColors.closeOrange
            : AppColors.farRed;

    final String instructionText = isAligned
        ? '¡ANTENA ALINEADA!'
        : deviation < 0
            ? 'GIRA ${absDev.toStringAsFixed(1)}° A LA IZQUIERDA'
            : 'GIRA ${absDev.toStringAsFixed(1)}° A LA DERECHA';

    final IconData instructionIcon = isAligned
        ? Icons.check_circle_outline
        : deviation < 0
            ? Icons.arrow_back_rounded
            : Icons.arrow_forward_rounded;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor, width: isAligned ? 2.5 : 1.2),
          boxShadow: isAligned
              ? [
                  BoxShadow(
                    color: AppColors.alignedGreen.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(instructionIcon, color: statusColor, size: 26),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    instructionText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // High performance custom painted deviation track
            SizedBox(
              height: 18,
              width: double.infinity,
              child: CustomPaint(
                painter: _DeviationTrackPainter(
                  deviation: deviation,
                  alignedTolerance: alignedTolerance,
                  statusColor: statusColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('-30°', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                Text('0° (Diana)', style: TextStyle(fontSize: 10, color: AppColors.alignedGreen, fontWeight: FontWeight.bold)),
                Text('+30°', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviationTrackPainter extends CustomPainter {
  final double deviation;
  final double alignedTolerance;
  final Color statusColor;

  _DeviationTrackPainter({
    required this.deviation,
    required this.alignedTolerance,
    required this.statusColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double centerY = size.height / 2;

    // 1. Background track
    final bgPaint = Paint()
      ..color = AppColors.surfaceVariant
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(3, centerY), Offset(width - 3, centerY), bgPaint);

    // 2. Center green target window
    final double toleranceWidth = (alignedTolerance / 30.0) * (width / 2);
    final targetWindowPaint = Paint()
      ..color = AppColors.alignedGreen.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final targetRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(width / 2, centerY),
        width: toleranceWidth * 2,
        height: 10,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(targetRect, targetWindowPaint);

    // 3. Center line (0° target mark)
    final centerMarkPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(width / 2, centerY - 8),
      Offset(width / 2, centerY + 8),
      centerMarkPaint,
    );

    // 4. Cursor position
    final double clampedDev = deviation.clamp(-30.0, 30.0);
    final double indicatorX = ((clampedDev + 30.0) / 60.0) * (width - 16) + 8;

    final cursorPaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(indicatorX, centerY), 6.0, cursorPaint);
    canvas.drawCircle(Offset(indicatorX, centerY), 6.0, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _DeviationTrackPainter oldDelegate) {
    return (oldDelegate.deviation - deviation).abs() > 0.05 ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.alignedTolerance != alignedTolerance;
  }
}
