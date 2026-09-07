import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/geo_calculator.dart';
import '../../data/models/tower_model.dart';

/// 60 FPS Card component displaying cell tower summary with technology badges and orientation CTA.
class TowerCard extends StatelessWidget {
  final TowerModel tower;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onAlign;
  final VoidCallback onDetails;

  const TowerCard({
    super.key,
    required this.tower,
    this.isSelected = false,
    required this.onSelect,
    required this.onAlign,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : tower.has5Gn78
                    ? AppColors.accent5G.withValues(alpha: 0.6)
                    : AppColors.outline,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Operator & Best Band Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.cell_tower,
                            color: tower.isMovistar ? AppColors.primary : AppColors.accentOther,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              tower.operator,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tower.has5Gn78)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent5G.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accent5G, width: 1.2),
                        ),
                        child: const Text(
                          'AFR 5G (3.5 GHz)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent5G,
                          ),
                        ),
                      )
                    else if (tower.has5Gn28)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent5GLow.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accent5GLow, width: 1.2),
                        ),
                        child: const Text(
                          '5G 700 MHz',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent5GLow,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Address
                Text(
                  tower.address,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Metrics Row: Distance & Azimuth
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'DISTANCIA',
                            style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            GeoCalculator.formatDistance(tower.distanceMeters),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 28, color: AppColors.outline),
                      Column(
                        children: [
                          const Text(
                            'RUMBO / AZIMUT',
                            style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tower.azimuthBearing.toStringAsFixed(0)}° (${GeoCalculator.bearingToCardinal(tower.azimuthBearing)})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action buttons (48dp min touch target)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onAlign,
                        icon: const Icon(Icons.explore, size: 18),
                        label: const Text('ALINEAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tower.has5Gn78 ? AppColors.accent5G : AppColors.primary,
                          foregroundColor: tower.has5Gn78 ? Colors.black : Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onDetails,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('INFO'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(80, 48),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
