import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';

/// Ultra-smooth 60 FPS GPU-accelerated compass dial for antenna alignment.
class CompassRose extends StatelessWidget {
  final double currentHeading;   // In degrees [0, 360)
  final double targetBearing;    // Target tower bearing [0, 360)
  final double toleranceDegrees; // e.g. 3.0°
  final double size;

  const CompassRose({
    super.key,
    required this.currentHeading,
    required this.targetBearing,
    this.toleranceDegrees = 3.0,
    this.size = 280.0,
  });

  @override
  Widget build(BuildContext context) {
    final deviation = GeoCalculator.calculateAngularDeviation(currentHeading, targetBearing);
    final isAligned = deviation.abs() <= toleranceDegrees;

    return RepaintBoundary(
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Static 360° Compass Dial (Rotated via Hardware GPU Texture Transform)
              Transform.rotate(
                angle: -currentHeading * math.pi / 180.0,
                child: CustomPaint(
                  size: Size(size, size),
                  painter: const _StaticCompassDialPainter(),
                  isComplex: true,
                  willChange: false,
                ),
              ),

              // 2. Dynamic Target Tower Sector & Chevron (Rotated to relative target angle)
              Transform.rotate(
                angle: (targetBearing - currentHeading) * math.pi / 180.0,
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _TargetIndicatorPainter(
                    toleranceDegrees: toleranceDegrees,
                    isAligned: isAligned,
                  ),
                ),
              ),

              // 3. Fixed Phone Heading Indicator (Top arrow pointing forward)
              Positioned(
                top: 8,
                child: CustomPaint(
                  size: const Size(20, 18),
                  painter: const _FixedDeviceArrowPainter(),
                ),
              ),

              // 4. Center Digital HUD Readout (Isolated layer)
              RepaintBoundary(
                child: Container(
                  width: size * 0.44,
                  height: size * 0.44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceVariant.withValues(alpha: 0.94),
                    border: Border.all(
                      color: isAligned ? AppColors.alignedGreen : AppColors.outline,
                      width: isAligned ? 3.0 : 1.5,
                    ),
                    boxShadow: isAligned
                        ? [
                            BoxShadow(
                              color: AppColors.alignedGreen.withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${currentHeading.toStringAsFixed(0)}°',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isAligned ? AppColors.alignedGreen : Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        GeoCalculator.bearingToCardinal(currentHeading),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TORRE: ${targetBearing.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static 360° Compass Dial Painter - painted ONCE and rotated by the GPU compositor.
class _StaticCompassDialPainter extends CustomPainter {
  const _StaticCompassDialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final dialPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, dialPaint);

    final ringPaint = Paint()
      ..color = AppColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, ringPaint);

    final tickPaint = Paint()
      ..color = AppColors.compassTick
      ..strokeWidth = 1.5;

    final majorTickPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.5;

    for (int i = 0; i < 360; i += 5) {
      final angleRad = (i - 90) * math.pi / 180.0;
      final bool isMajor = i % 30 == 0;
      final double tickLength = isMajor ? 12.0 : 6.0;

      final p1 = Offset(
        center.dx + (radius - 2) * math.cos(angleRad),
        center.dy + (radius - 2) * math.sin(angleRad),
      );
      final p2 = Offset(
        center.dx + (radius - 2 - tickLength) * math.cos(angleRad),
        center.dy + (radius - 2 - tickLength) * math.sin(angleRad),
      );

      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);

      // Cardinal Letters (N, E, S, W)
      if (i % 90 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: i == 0 ? 'N' : i == 90 ? 'E' : i == 180 ? 'S' : 'W',
            style: TextStyle(
              color: i == 0 ? Colors.redAccent : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final textOffset = Offset(
          center.dx + (radius - 26) * math.cos(angleRad) - textPainter.width / 2,
          center.dy + (radius - 26) * math.sin(angleRad) - textPainter.height / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Target Tower Sector and Chevron Pointer Painter.
class _TargetIndicatorPainter extends CustomPainter {
  final double toleranceDegrees;
  final bool isAligned;

  _TargetIndicatorPainter({
    required this.toleranceDegrees,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const double targetAngleRad = -math.pi / 2; // Pointing straight up in its own frame
    final double toleranceRad = toleranceDegrees * math.pi / 180.0;

    // Tolerance cone
    final conePaint = Paint()
      ..color = (isAligned ? AppColors.alignedGreen : AppColors.primary).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      targetAngleRad - toleranceRad,
      toleranceRad * 2,
      true,
      conePaint,
    );

    // Target Needle / Chevron on the rim
    final targetIndicatorPaint = Paint()
      ..color = isAligned ? AppColors.alignedGreen : AppColors.accent5G
      ..style = PaintingStyle.fill;

    final targetTip = Offset(
      center.dx,
      center.dy - (radius - 2),
    );
    final leftCorner = Offset(
      center.dx - 12,
      center.dy - (radius - 18),
    );
    final rightCorner = Offset(
      center.dx + 12,
      center.dy - (radius - 18),
    );

    final path = Path()
      ..moveTo(targetTip.dx, targetTip.dy)
      ..lineTo(leftCorner.dx, leftCorner.dy)
      ..lineTo(rightCorner.dx, rightCorner.dy)
      ..close();
    canvas.drawPath(path, targetIndicatorPaint);
  }

  @override
  bool shouldRepaint(covariant _TargetIndicatorPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned ||
        oldDelegate.toleranceDegrees != toleranceDegrees;
  }
}

/// Fixed Device Arrow Painter at the top of the HUD.
class _FixedDeviceArrowPainter extends CustomPainter {
  const _FixedDeviceArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
