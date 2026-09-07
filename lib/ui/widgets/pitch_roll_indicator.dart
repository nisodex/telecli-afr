import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// High-performance 60 FPS bubble level and pitch/roll tilt instrument.
class PitchRollIndicator extends StatelessWidget {
  final double pitch; // Front/back tilt degrees (-90 to +90)
  final double roll;  // Left/right tilt degrees (-180 to +180)
  final double targetTilt; // Target elevation tilt degrees (defaults to 0.0)

  const PitchRollIndicator({
    super.key,
    required this.pitch,
    required this.roll,
    this.targetTilt = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final double tiltDeviation = (pitch - targetTilt).abs();
    final bool isLevel = tiltDeviation <= 2.0 && roll.abs() <= 2.0;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            // Bubble level visual
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceVariant,
                border: Border.all(
                  color: isLevel ? AppColors.alignedGreen : AppColors.outline,
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Crosshairs (static)
                  const _LevelCrosshairs(),
                  // Center target ring (static)
                  _LevelCenterRing(isLevel: isLevel),
                  // Bubble (clamped to circle radius, hardware transformed)
                  Transform.translate(
                    offset: Offset(
                      (roll * 1.5).clamp(-22.0, 22.0),
                      (-pitch * 1.5).clamp(-22.0, 22.0),
                    ),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLevel ? AppColors.alignedGreen : AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: (isLevel ? AppColors.alignedGreen : AppColors.primary)
                                .withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Numeric readouts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NIVEL Y ELEVACIÓN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Inclinación: ${pitch.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Obj: ${targetTilt.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Plomada: ${roll.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isLevel ? 'NIVELADO' : 'AJUSTAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLevel ? AppColors.alignedGreen : AppColors.closeOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCrosshairs extends StatelessWidget {
  const _LevelCrosshairs();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(width: 1, height: 70, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.outline))),
        SizedBox(width: 70, height: 1, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.outline))),
      ],
    );
  }
}

class _LevelCenterRing extends StatelessWidget {
  final bool isLevel;

  const _LevelCenterRing({required this.isLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isLevel ? AppColors.alignedGreen : AppColors.onSurfaceVariant,
          width: 1.5,
        ),
      ),
    );
  }
}
