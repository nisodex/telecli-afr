import 'package:flutter/material.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';
import 'package:telecli_afr/core/utils/rf_calculator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/services/sensors_service.dart';

/// Advanced RF Engineering Telemetry Card for Field Technicians.
class RfTelemetryCard extends StatefulWidget {
  final TowerModel tower;
  final DeviceOrientationData? sensorData;
  final double currentHeading;
  final double clientLat;
  final double clientLon;
  final VoidCallback? onOpenCalculator;

  const RfTelemetryCard({
    super.key,
    required this.tower,
    this.sensorData,
    required this.currentHeading,
    required this.clientLat,
    required this.clientLon,
    this.onOpenCalculator,
  });

  @override
  State<RfTelemetryCard> createState() => _RfTelemetryCardState();
}

class _RfTelemetryCardState extends State<RfTelemetryCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final double dist = widget.tower.distanceMeters;
    final bool isN78 = widget.tower.has5Gn78;
    final double freqMhz = isN78 ? RfCalculator.freq5Gn78Mhz : RfCalculator.freq5Gn28Mhz;

    // Mathematical RF Computations
    final double fsplDb = RfCalculator.calculateFspl(dist, freqMhz);
    final double fresnelR1 = RfCalculator.calculateFresnelRadius(dist, freqMhz);
    final double fresnel60 = RfCalculator.calculateFresnel60PercentClearance(dist, freqMhz);
    final double estimatedRsrp = RfCalculator.estimateRsrp(distanceMeters: dist, isN78: isN78);
    final quality = RfCalculator.evaluateSignalQuality(estimatedRsrp);
    final int throughputMbps = RfCalculator.estimateDownlinkThroughput(rsrpDbm: estimatedRsrp, isN78: isN78);

    final double angularDev = GeoCalculator.calculateAngularDeviation(
      widget.currentHeading,
      widget.tower.azimuthBearing,
    );
    final bool inMainBeam = RfCalculator.isInsideMainBeam(angularDeviation: angularDev, isN78: isN78);
    final double declination = RfCalculator.estimateMagneticDeclination(widget.clientLat, widget.clientLon);

    final bool hasDisturbance = widget.sensorData?.hasMagneticDisturbance ?? false;
    final double magUt = widget.sensorData?.magneticFieldMicroTesla ?? 45.0;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDisturbance ? AppColors.accentWarning : AppColors.outline,
          width: hasDisturbance ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Expand/Collapse toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TELEMETRÍA RF Y ENLACE AVANZADO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Cálculos en tiempo real según estándar 3GPP FWA',
                          style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onOpenCalculator != null)
                    IconButton(
                      icon: const Icon(Icons.calculate_outlined, size: 20, color: AppColors.primary),
                      tooltip: 'Simulador de Enlace RF',
                      onPressed: widget.onOpenCalculator,
                    ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: AppColors.outline),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: RSRP Estimado & Throughput Teórico
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryBox(
                          title: 'RSRP ESTIMADO',
                          value: '${estimatedRsrp.toStringAsFixed(1)} dBm',
                          badge: quality == SignalQualityTier.excellent
                              ? 'EXCELENTE'
                              : quality == SignalQualityTier.good
                                  ? 'BUENO (AFR OK)'
                                  : 'MARGINAL',
                          badgeColor: quality == SignalQualityTier.excellent
                              ? AppColors.accent5G
                              : quality == SignalQualityTier.good
                                  ? AppColors.primary
                                  : AppColors.accentWarning,
                          icon: Icons.signal_cellular_alt,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTelemetryBox(
                          title: 'DOWNLINK TEÓRICO',
                          value: '$throughputMbps Mbps',
                          badge: isN78 ? 'BANDA n78 (100MHz)' : 'BANDA n28 (20MHz)',
                          badgeColor: isN78 ? AppColors.accent5G : AppColors.accent5GLow,
                          icon: Icons.speed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: FSPL & 1ª Zona Fresnel
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryBox(
                          title: 'PÉRDIDA TRAYECTORIA (FSPL)',
                          value: '${fsplDb.toStringAsFixed(1)} dB',
                          badge: 'Espacio Libre',
                          badgeColor: AppColors.onSurfaceVariant,
                          icon: Icons.waves,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTelemetryBox(
                          title: '1ª ZONA FRESNEL (r₁)',
                          value: '${fresnelR1.toStringAsFixed(2)} m',
                          badge: 'Despeje 60%: ${fresnel60.toStringAsFixed(2)} m',
                          badgeColor: AppColors.primary,
                          icon: Icons.adjust,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 3: Lóbulo de Antena HPBW & Declinación Magnética
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: inMainBeam ? AppColors.alignedGreen : AppColors.accentWarning,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          inMainBeam ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          color: inMainBeam ? AppColors.alignedGreen : AppColors.accentWarning,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inMainBeam
                                    ? 'DENTRO DEL LÓBULO PRINCIPAL (HPBW)'
                                    : 'FUERA DEL LÓBULO PRINCIPAL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: inMainBeam ? AppColors.alignedGreen : AppColors.accentWarning,
                                ),
                              ),
                              Text(
                                'Apertura de haz: ${isN78 ? '±15° (3.5 GHz)' : '±35° (700 MHz)'} • Desv: ${angularDev.abs().toStringAsFixed(1)}°',
                                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Magnetic Disturbance & Sensor Calibration Warning
                  if (hasDisturbance)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentWarning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentWarning),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.electric_bolt, color: AppColors.accentWarning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Interferencia electromagnética detectada (${magUt.toStringAsFixed(0)} μT). Aléjate del mástil metálico al calibrar la brújula.',
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Sensor Telemetry Details Bar
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildSensorPill(
                        'Declinación Mag:',
                        '${declination >= 0 ? '+' : ''}${declination.toStringAsFixed(1)}°',
                      ),
                      _buildSensorPill(
                        'Campo Mag:',
                        '${magUt.toStringAsFixed(1)} μT',
                      ),
                      _buildSensorPill(
                        'Precisión Sensor:',
                        '±${(widget.sensorData?.accuracy ?? 5.0).toStringAsFixed(0)}°',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildTelemetryBox({
    required String title,
    required String value,
    required String badge,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorPill(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          Text(
            val,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
