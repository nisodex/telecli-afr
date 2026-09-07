import 'package:flutter/material.dart';
import 'package:telecli_afr/core/constants/movistar_constants.dart';
import 'package:telecli_afr/core/di/service_locator.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';
import 'package:telecli_afr/core/utils/rf_calculator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/services/location_service.dart';
import 'package:telecli_afr/ui/core/widgets/compass_rose.dart';
import 'package:telecli_afr/ui/core/widgets/pitch_roll_indicator.dart';
import 'package:telecli_afr/ui/core/widgets/rf_calculator_sheet.dart';
import 'package:telecli_afr/ui/core/widgets/rf_telemetry_card.dart';
import 'package:telecli_afr/ui/core/widgets/signal_gauge.dart';
import '../view_models/alignment_view_model.dart';
import 'ar_view_screen.dart';

/// Main Antenna Orientation HUD Screen for the field technician.
/// Architected for 60 FPS zero-lag operation using surgical ValueNotifiers and RepaintBoundaries.
class CompassAlignmentScreen extends StatefulWidget {
  final TowerModel tower;
  final double clientLat;
  final double clientLon;
  final String clientAddress;
  final AlignmentViewModel? viewModel;

  const CompassAlignmentScreen({
    super.key,
    required this.tower,
    required this.clientLat,
    required this.clientLon,
    this.clientAddress = '',
    this.viewModel,
  });

  @override
  State<CompassAlignmentScreen> createState() => _CompassAlignmentScreenState();
}

class _CompassAlignmentScreenState extends State<CompassAlignmentScreen> {
  late final AlignmentViewModel _viewModel;
  bool _ownsViewModel = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      _viewModel = ServiceLocator.createAlignmentViewModel(
        tower: widget.tower,
        clientLat: widget.clientLat,
        clientLon: widget.clientLon,
        clientAddress: widget.clientAddress,
      );
      _ownsViewModel = true;
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
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
    final currentPitch = _viewModel.pitchNotifier.value;
    final currentHeading = _viewModel.headingNotifier.value;

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
              await _viewModel.saveInstallationJob(
                clientName: clientNameController.text,
                notes: notesController.text,
                rsrpDbm: int.tryParse(rssiController.text),
                currentPitch: currentPitch,
                currentHeading: currentHeading,
              );

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
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) {
              final haptic = _viewModel.hapticEnabled;
              return IconButton(
                icon: Icon(
                  haptic ? Icons.vibration : Icons.smartphone,
                  color: haptic ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
                tooltip: haptic ? 'Vibración de alineación activa' : 'Vibración desactivada',
                onPressed: _viewModel.toggleHaptic,
              );
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
                    viewModel: _viewModel,
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
                valueListenable: _viewModel.headingNotifier,
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
                valueListenable: _viewModel.headingNotifier,
                builder: (context, heading, _) {
                  final dev = _viewModel.calculateDeviation(heading);
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
                animation: Listenable.merge([_viewModel.pitchNotifier, _viewModel.rollNotifier]),
                builder: (context, _) {
                  return PitchRollIndicator(
                    pitch: _viewModel.pitchNotifier.value,
                    roll: _viewModel.rollNotifier.value,
                    targetTilt: widget.tower.elevationTilt,
                  );
                },
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: Listenable.merge([_viewModel.headingNotifier, _viewModel.orientationNotifier]),
                builder: (context, _) {
                  return RfTelemetryCard(
                    tower: widget.tower,
                    sensorData: _viewModel.orientationNotifier.value,
                    currentHeading: _viewModel.headingNotifier.value,
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
                              viewModel: _viewModel,
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
                      valueListenable: _viewModel.headingNotifier,
                      builder: (context, heading, _) {
                        final isAligned = _viewModel.isHeadingAligned(heading);

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
