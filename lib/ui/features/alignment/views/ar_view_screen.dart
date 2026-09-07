import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:telecli_afr/core/di/service_locator.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import '../view_models/alignment_view_model.dart';

/// Ultra-smooth 60 FPS Augmented Reality (AR) Camera Screen superimposing Movistar towers on the horizon.
class ArViewScreen extends StatefulWidget {
  final TowerModel tower;
  final double clientLat;
  final double clientLon;
  final double clientAltitude;
  final AlignmentViewModel? viewModel;

  const ArViewScreen({
    super.key,
    required this.tower,
    required this.clientLat,
    required this.clientLon,
    this.clientAltitude = 644.0,
    this.viewModel,
  });

  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends State<ArViewScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _cameraError = false;

  late final AlignmentViewModel _viewModel;
  bool _ownsViewModel = false;
  late final AnimationController _pulseController;

  static const double kDefaultTowerHeight = 28.0; // Typical urban/rooftop 5G mast height in meters

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
      );
      _ownsViewModel = true;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final backCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraReady = true;
          });
        }
      } else {
        if (mounted) setState(() => _cameraError = true);
      }
    } catch (e) {
      debugPrint('[ArViewScreen] Camera initialization error: $e');
      if (mounted) {
        setState(() => _cameraError = true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double elevationTilt = _viewModel.elevationTilt;
    final double totalCota = widget.clientAltitude + kDefaultTowerHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera hardware texture layer (Never rebuilds on sensor ticks)
          if (_isCameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            _buildSimulatedCameraBackground(),

          // 2. Horizon reference & Central Crosshair / Reticle
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_viewModel.headingNotifier, _viewModel.pitchNotifier]),
              builder: (context, _) {
                final heading = _viewModel.headingNotifier.value;
                final pitch = _viewModel.pitchNotifier.value;
                final bool isAligned = _viewModel.isFullyAligned(heading, pitch, targetElevationTilt: elevationTilt);

                return Stack(
                  children: [
                    // Center Reticle
                    Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isAligned ? AppColors.alignedGreen : Colors.white.withValues(alpha: 0.65),
                            width: isAligned ? 3.0 : 1.5,
                          ),
                          boxShadow: isAligned
                              ? [
                                  BoxShadow(
                                    color: AppColors.alignedGreen.withValues(alpha: 0.6),
                                    blurRadius: 24,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 2,
                              color: isAligned ? AppColors.alignedGreen : Colors.white70,
                            ),
                            Container(
                              width: 2,
                              height: 32,
                              color: isAligned ? AppColors.alignedGreen : Colors.white70,
                            ),
                            if (isAligned)
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.alignedGreen,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Artificial horizon line
                    Positioned(
                      left: 20,
                      right: 20,
                      top: ((MediaQuery.of(context).size.height / 2.0) +
                              (pitch / 25.0) * (MediaQuery.of(context).size.height / 2.0))
                          .clamp(90.0, MediaQuery.of(context).size.height - 110.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${pitch.toStringAsFixed(1)}°',
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. 60 FPS AR Projected Tower Marker (Mapped within 60° Horizontal FOV)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _viewModel.headingNotifier,
                _viewModel.pitchNotifier,
                _pulseController,
              ]),
              builder: (context, _) {
                final heading = _viewModel.headingNotifier.value;
                final pitch = _viewModel.pitchNotifier.value;
                final deviation = _viewModel.calculateDeviation(heading);
                final pitchDiff = pitch - elevationTilt;
                final bool isAligned = _viewModel.isFullyAligned(heading, pitch, targetElevationTilt: elevationTilt);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final screenHeight = constraints.maxHeight;
                    const double hFovDegrees = 60.0;
                    const double vFovDegrees = 50.0;

                    // Tower marker horizontal offset
                    final double normalizedX = (deviation / (hFovDegrees / 2.0));
                    final double markerX = (screenWidth / 2.0) + (normalizedX * (screenWidth / 2.0));

                    // Tower marker vertical offset according to pitch tilt vs target elevation tilt
                    final double normalizedY = (pitchDiff / (vFovDegrees / 2.0));
                    final double markerY = (screenHeight / 2.0) + (normalizedY * (screenHeight / 2.0));

                    final bool isInsideFov = deviation.abs() <= (hFovDegrees / 2.0) &&
                        pitchDiff.abs() <= (vFovDegrees / 2.0);
                    final bool isLeft = deviation < 0;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (isInsideFov)
                          Positioned(
                            left: (markerX - 28).clamp(16.0, screenWidth - 72.0),
                            top: (markerY - 28).clamp(120.0, screenHeight - 140.0),
                            child: _buildArTowerTargetCard(
                              isAligned: isAligned,
                              elevationTilt: elevationTilt,
                              towerHeight: kDefaultTowerHeight,
                              totalCota: totalCota,
                              pitchDiff: pitchDiff,
                            ),
                          )
                        else
                          Positioned(
                            left: isLeft ? 16 : null,
                            right: isLeft ? null : 16,
                            top: (screenHeight / 2.0) - 40,
                            child: _buildOffScreenAntennaBeacon(
                              isLeft: isLeft,
                              deviation: deviation,
                              pitchDiff: pitchDiff,
                              elevationTilt: elevationTilt,
                              towerHeight: kDefaultTowerHeight,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // 4. Fixed Top HUD Header with Complete Technical Telemetry
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder<double>(
                valueListenable: _viewModel.headingNotifier,
                builder: (context, heading, _) {
                  final bool isAligned = _viewModel.isHeadingAligned(heading);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isAligned ? AppColors.alignedGreen : AppColors.outline),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        widget.tower.has5Gn78 ? 'MOVISTAR 5G (n78)' : 'MOVISTAR 5G (n28)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: widget.tower.has5Gn78 ? AppColors.accent5G : AppColors.accent5GLow,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        GeoCalculator.formatDistance(widget.tower.distanceMeters),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rumbo: ${widget.tower.azimuthBearing.toStringAsFixed(0)}° (${GeoCalculator.bearingToCardinal(widget.tower.azimuthBearing)})',
                                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Fixed Telemetry Row (Altura mástil, Cota antena, Tilt óptimo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildHeaderTelemetryItem('Altura mástil', '${kDefaultTowerHeight.toStringAsFixed(1)} m', Colors.white),
                              Container(width: 1, height: 22, color: AppColors.outline),
                              _buildHeaderTelemetryItem('Cota antena', '${totalCota.toStringAsFixed(0)} m', AppColors.primary),
                              Container(width: 1, height: 22, color: AppColors.accent5G),
                              _buildHeaderTelemetryItem('Tilt óptimo', '${elevationTilt >= 0 ? '+' : ''}${elevationTilt.toStringAsFixed(1)}°', AppColors.accent5G),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 5. Bottom Alignment Instruction Bar
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedBuilder(
                animation: Listenable.merge([_viewModel.headingNotifier, _viewModel.pitchNotifier]),
                builder: (context, _) {
                  final heading = _viewModel.headingNotifier.value;
                  final pitch = _viewModel.pitchNotifier.value;
                  final dev = _viewModel.calculateDeviation(heading);
                  final pitchDiff = pitch - elevationTilt;
                  final bool isHeadingAligned = _viewModel.isHeadingAligned(heading);
                  final bool isPitchAligned = _viewModel.isPitchAligned(pitch, targetElevationTilt: elevationTilt);
                  final bool isFullyAligned = isHeadingAligned && isPitchAligned;

                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: (isFullyAligned ? AppColors.alignedGreen : AppColors.surface).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isFullyAligned
                          ? [
                              BoxShadow(
                                color: AppColors.alignedGreen.withValues(alpha: 0.4),
                                blurRadius: 16,
                              )
                            ]
                          : const [
                              BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFullyAligned ? Icons.check_circle : Icons.cell_tower,
                          color: isFullyAligned ? Colors.black : AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            isFullyAligned
                                ? '¡ANTENA 5G EN LÍNEA DE VISIÓN DIRECTA!'
                                : !isHeadingAligned
                                    ? dev < 0
                                        ? 'GIRA ${dev.abs().toStringAsFixed(1)}° A LA IZQUIERDA'
                                        : 'GIRA ${dev.abs().toStringAsFixed(1)}° A LA DERECHA'
                                    : pitchDiff > 0
                                        ? 'INCLINA ${pitchDiff.abs().toStringAsFixed(1)}° ABAJO (TILT)'
                                        : 'INCLINA ${pitchDiff.abs().toStringAsFixed(1)}° ARRIBA (TILT)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isFullyAligned ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// High-visibility, lightweight AR 3D Antenna Target Pin for aiming (no bulky jittering card)
  Widget _buildArTowerTargetCard({
    required bool isAligned,
    required double elevationTilt,
    required double towerHeight,
    required double totalCota,
    required double pitchDiff,
  }) {
    final Color accentColor = isAligned ? AppColors.alignedGreen : (widget.tower.has5Gn78 ? AppColors.accent5G : AppColors.primary);
    final double pulseScale = isAligned ? (1.0 + (_pulseController.value * 0.18)) : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Animated Glowing Antenna Reticle & Icon
        Transform.scale(
          scale: pulseScale,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.90),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor,
                width: isAligned ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: isAligned ? 0.75 : 0.40),
                  blurRadius: isAligned ? 22 : 12,
                  spreadRadius: isAligned ? 3 : 1,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.cell_tower,
                color: accentColor,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // 2. Compact, stable target label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isAligned ? AppColors.alignedGreen : AppColors.surface).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor, width: 1.0),
          ),
          child: Text(
            isAligned ? '⌖ ALINEADO' : 'ANTENA 5G',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isAligned ? Colors.black : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Compact telemetry item for fixed Top HUD Header
  Widget _buildHeaderTelemetryItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  /// Off-Screen Guidance Pointer docked to screen edge with Antenna Icon & Angle
  Widget _buildOffScreenAntennaBeacon({
    required bool isLeft,
    required double deviation,
    required double pitchDiff,
    required double elevationTilt,
    required double towerHeight,
  }) {
    final bool needsPitchFix = pitchDiff.abs() > 8.0;
    final String pitchHint = pitchDiff > 0 ? '↓ Baja ${pitchDiff.abs().toStringAsFixed(0)}°' : '↑ Sube ${pitchDiff.abs().toStringAsFixed(0)}°';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft)
            const Icon(Icons.arrow_back, color: AppColors.primary, size: 22)
          else
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cell_tower, color: AppColors.primary, size: 18),
            ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                '${deviation.abs().toStringAsFixed(0)}° ${isLeft ? '← IZQ' : 'DER →'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              if (needsPitchFix)
                Text(
                  pitchHint,
                  style: const TextStyle(
                    color: AppColors.accentWarning,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              Text(
                'Antena: ${GeoCalculator.formatDistance(widget.tower.distanceMeters)} • ${towerHeight.toStringAsFixed(0)}m',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          if (!isLeft)
            const Icon(Icons.arrow_forward, color: AppColors.primary, size: 22)
          else
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cell_tower, color: AppColors.primary, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildSimulatedCameraBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Text(
              _cameraError
                  ? 'Cámara no disponible (Modo simulación AR)'
                  : 'Visor AR (Iniciando horizonte...)',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }
}
