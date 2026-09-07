import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/movistar_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/geo_calculator.dart';
import '../../core/utils/rf_calculator.dart';
import '../../data/models/installation_job.dart';
import '../../data/models/tower_model.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/sensors_service.dart';
import '../widgets/compass_rose.dart';
import '../widgets/pitch_roll_indicator.dart';
import '../widgets/rf_calculator_sheet.dart';
import '../widgets/rf_telemetry_card.dart';
import '../widgets/signal_gauge.dart';
import 'ar_view_screen.dart';

/// Main Antenna Orientation HUD Screen for the field technician.
/// Architected for 60 FPS zero-lag operation using surgical ValueNotifiers and RepaintBoundaries.
class CompassAlignmentScreen extends StatefulWidget {
  final TowerModel tower;
  final double clientLat;
  final double clientLon;
  final String clientAddress;

  const CompassAlignmentScreen({
    super.key,
    required this.tower,
    required this.clientLat,
    required this.clientLon,
    this.clientAddress = '',
  });

  @override
  State<CompassAlignmentScreen> createState() => _CompassAlignmentScreenState();
}

class _CompassAlignmentScreenState extends State<CompassAlignmentScreen> {
  final SensorsService _sensorsService = SensorsService();
  StreamSubscription<DeviceOrientationData>? _sensorSub;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _sensorsService.startListening();

    // Haptic feedback listener runs in background without triggering setState()
    _sensorSub = _sensorsService.orientationStream.listen((data) {
      if (_hapticEnabled) {
        final dev = GeoCalculator.calculateAngularDeviation(data.heading, widget.tower.azimuthBearing);
        _sensorsService.triggerAlignmentHaptic(
          dev,
          alignedTolerance: MovistarConstants.defaultAlignedToleranceDegrees,
        );
      }
    });
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _sensorsService.dispose();
    super.dispose();
  }

  void _openCalculatorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: RfCalculatorSheet(tower: widget.tower),
      ),
    );
  }

  void _showSaveJobDialog() {
    final bool isN78 = widget.tower.has5Gn78;
    final double freqMhz = isN78 ? RfCalculator.freq5Gn78Mhz : RfCalculator.freq5Gn28Mhz;
    final double fsplDb = RfCalculator.calculateFspl(widget.tower.distanceMeters, freqMhz);
    final double fresnelR1 = RfCalculator.calculateFresnelRadius(widget.tower.distanceMeters, freqMhz);
    final double estimatedRsrp = RfCalculator.estimateRsrp(
      distanceMeters: widget.tower.distanceMeters,
      isN78: isN78,
    );
    final int estThroughput = RfCalculator.estimateDownlinkThroughput(
      rsrpDbm: estimatedRsrp,
      isN78: isN78,
    );
    final double declination = RfCalculator.estimateMagneticDeclination(widget.clientLat, widget.clientLon);
    final currentPitch = _sensorsService.pitchNotifier.value;

    final clientNameController = TextEditingController();
    final notesController = TextEditingController();
    final rssiController = TextEditingController(text: estimatedRsrp.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.save_alt, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Guardar Instalación AFR 5G', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Technical RF parameters preview banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('FSPL', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                        Text('${fsplDb.toStringAsFixed(1)} dB', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('1ª Fresnel', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                        Text('${fresnelR1.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Tilt Real', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                        Text('${currentPitch.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent5G)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre / Contrato Cliente',
                  hintText: 'Ej: Juan Pérez / FWA-8921',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rssiController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nivel Señal RSRP Medido (dBm)',
                  hintText: 'Ej: -78',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observaciones Técnicas / Herraje',
                  hintText: 'Ej: Mástil 48mm galvanizado, despeje LOS verificado',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              final job = InstallationJob(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                clientName: clientNameController.text.trim().isEmpty
                    ? 'Cliente AFR 5G'
                    : clientNameController.text.trim(),
                clientAddress: widget.clientAddress.isNotEmpty
                    ? widget.clientAddress
                    : '${widget.clientLat.toStringAsFixed(4)}, ${widget.clientLon.toStringAsFixed(4)}',
                clientLat: widget.clientLat,
                clientLon: widget.clientLon,
                towerId: widget.tower.id,
                towerCode: widget.tower.code,
                towerAddress: widget.tower.address,
                targetBearing: widget.tower.azimuthBearing,
                distanceMeters: widget.tower.distanceMeters,
                technologyBand: widget.tower.has5Gn78 ? '5G n78 (3.5 GHz)' : '5G n28 (700 MHz)',
                rsrpDbm: int.tryParse(rssiController.text),
                notes: notesController.text.trim(),
                createdAt: DateTime.now(),
                fsplDb: fsplDb,
                fresnelRadiusMeters: fresnelR1,
                estimatedRsrpDbm: estimatedRsrp,
                downlinkEstimatedMbps: estThroughput,
                mechanicalTiltDeg: currentPitch,
                magneticDeclinationDeg: declination,
                gpsAccuracyMeters: _sensorsService.orientationNotifier.value.accuracy,
              );

              await LocalStorageService().saveJob(job);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Instalación y Boletín RF registrados correctamente!'),
                    backgroundColor: AppColors.alignedGreen,
                  ),
                );
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orientador de Antena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined, color: AppColors.primary),
            tooltip: 'Calculadora de Enlace RF',
            onPressed: _openCalculatorModal,
          ),
          IconButton(
            icon: Icon(
              _hapticEnabled ? Icons.vibration : Icons.smartphone,
              color: _hapticEnabled ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            tooltip: _hapticEnabled ? 'Vibración de alineación activa' : 'Vibración desactivada',
            onPressed: () {
              setState(() {
                _hapticEnabled = !_hapticEnabled;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt, color: AppColors.accent5G),
            tooltip: 'Modo Realidad Aumentada (Cámara)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArViewScreen(
                    tower: widget.tower,
                    clientLat: widget.clientLat,
                    clientLon: widget.clientLon,
                    clientAltitude: LocationService.lastPosition?.altitude ?? 644.0,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 720.0;

          final Widget leftColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTargetHeaderCard(),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: _sensorsService.headingNotifier,
                builder: (context, heading, _) {
                  return CompassRose(
                    currentHeading: heading,
                    targetBearing: widget.tower.azimuthBearing,
                    toleranceDegrees: MovistarConstants.defaultAlignedToleranceDegrees,
                    size: isWide ? 280 : 260,
                  );
                },
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: _sensorsService.headingNotifier,
                builder: (context, heading, _) {
                  final dev = GeoCalculator.calculateAngularDeviation(heading, widget.tower.azimuthBearing);
                  return SignalGauge(
                    deviation: dev,
                    alignedTolerance: MovistarConstants.defaultAlignedToleranceDegrees,
                    warningTolerance: MovistarConstants.defaultWarningToleranceDegrees,
                  );
                },
              ),
            ],
          );

          final Widget rightColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_sensorsService.pitchNotifier, _sensorsService.rollNotifier]),
                builder: (context, _) {
                  return PitchRollIndicator(
                    pitch: _sensorsService.pitchNotifier.value,
                    roll: _sensorsService.rollNotifier.value,
                    targetTilt: widget.tower.elevationTilt,
                  );
                },
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: Listenable.merge([_sensorsService.headingNotifier, _sensorsService.orientationNotifier]),
                builder: (context, _) {
                  return RfTelemetryCard(
                    tower: widget.tower,
                    sensorData: _sensorsService.orientationNotifier.value,
                    currentHeading: _sensorsService.headingNotifier.value,
                    clientLat: widget.clientLat,
                    clientLon: widget.clientLon,
                    onOpenCalculator: _openCalculatorModal,
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArViewScreen(
                              tower: widget.tower,
                              clientLat: widget.clientLat,
                              clientLon: widget.clientLon,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.videocam, size: 20),
                      label: const Text('VISOR CÁMARA AR'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _sensorsService.headingNotifier,
                      builder: (context, heading, _) {
                        final dev = GeoCalculator.calculateAngularDeviation(heading, widget.tower.azimuthBearing);
                        final isAligned = dev.abs() <= MovistarConstants.defaultAlignedToleranceDegrees;

                        return ElevatedButton.icon(
                          onPressed: _showSaveJobDialog,
                          icon: const Icon(Icons.check, size: 20),
                          label: const Text('GUARDAR OBRA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAligned ? AppColors.alignedGreen : AppColors.primary,
                            foregroundColor: isAligned ? Colors.black : Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: leftColumn),
                          const SizedBox(width: 20),
                          Expanded(flex: 1, child: rightColumn),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          leftColumn,
                          const SizedBox(height: 16),
                          rightColumn,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTargetHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cell_tower, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.tower.has5Gn78 ? 'MOVISTAR AFR 5G (n78)' : 'MOVISTAR 5G (n28)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: widget.tower.has5Gn78 ? AppColors.accent5G : AppColors.accent5GLow,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        GeoCalculator.formatDistance(widget.tower.distanceMeters),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  widget.tower.address,
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
