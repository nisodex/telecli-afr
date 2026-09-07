import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:telecli_afr/core/constants/movistar_constants.dart';
import 'package:telecli_afr/core/di/service_locator.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';
import 'package:telecli_afr/data/models/installation_job.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/repositories/installation_job_repository.dart';
import 'package:telecli_afr/data/services/sensors_service.dart';
import 'package:telecli_afr/domain/use_cases/calculate_rf_link_use_case.dart';

/// ViewModel managing state, telemetry, haptic cues, and job registration for antenna alignment.
class AlignmentViewModel extends ChangeNotifier {
  final TowerModel tower;
  final double clientLat;
  final double clientLon;
  final String clientAddress;

  final SensorsService _sensorsService;
  final InstallationJobRepository _jobRepository;
  final CalculateRfLinkUseCase _calculateRfLinkUseCase;

  StreamSubscription<DeviceOrientationData>? _sensorSub;
  bool _hapticEnabled = true;
  bool _isDisposed = false;

  static const double defaultTowerHeightMeters = 28.0;

  AlignmentViewModel({
    required this.tower,
    required this.clientLat,
    required this.clientLon,
    this.clientAddress = '',
    SensorsService? sensorsService,
    InstallationJobRepository? jobRepository,
    CalculateRfLinkUseCase? calculateRfLinkUseCase,
  })  : _sensorsService = sensorsService ?? ServiceLocator.createSensorsService(),
        _jobRepository = jobRepository ?? ServiceLocator.installationJobRepository,
        _calculateRfLinkUseCase = calculateRfLinkUseCase ?? ServiceLocator.calculateRfLinkUseCase {
    _initSensors();
  }

  // 60 FPS Hardware ValueNotifiers exposed directly for zero-rebuild surgical UI performance
  ValueNotifier<double> get headingNotifier => _sensorsService.headingNotifier;
  ValueNotifier<double> get pitchNotifier => _sensorsService.pitchNotifier;
  ValueNotifier<double> get rollNotifier => _sensorsService.rollNotifier;
  ValueNotifier<DeviceOrientationData> get orientationNotifier => _sensorsService.orientationNotifier;
  Stream<DeviceOrientationData> get orientationStream => _sensorsService.orientationStream;

  SensorsService get sensorsService => _sensorsService;
  bool get hapticEnabled => _hapticEnabled;

  double get elevationTilt => GeoCalculator.calculateElevationTilt(
        tower.distanceMeters,
        0.0,
        defaultTowerHeightMeters,
      );

  void _initSensors() {
    _sensorsService.startListening();
    _sensorSub = _sensorsService.orientationStream.listen((data) {
      if (_hapticEnabled) {
        final dev = calculateDeviation(data.heading);
        _sensorsService.triggerAlignmentHaptic(
          dev,
          alignedTolerance: MovistarConstants.defaultAlignedToleranceDegrees,
        );
      }
    });
  }

  void toggleHaptic() {
    _hapticEnabled = !_hapticEnabled;
    notifyListeners();
  }

  double calculateDeviation(double currentHeading) {
    return GeoCalculator.calculateAngularDeviation(currentHeading, tower.azimuthBearing);
  }

  bool isHeadingAligned(double currentHeading) {
    return calculateDeviation(currentHeading).abs() <= MovistarConstants.defaultAlignedToleranceDegrees;
  }

  bool isPitchAligned(double currentPitch, {double? targetElevationTilt}) {
    final target = targetElevationTilt ?? elevationTilt;
    return (currentPitch - target).abs() <= MovistarConstants.defaultAlignedToleranceDegrees;
  }

  bool isFullyAligned(double currentHeading, double currentPitch, {double? targetElevationTilt}) {
    return isHeadingAligned(currentHeading) && isPitchAligned(currentPitch, targetElevationTilt: targetElevationTilt);
  }

  RfLinkTelemetry calculateRfLink({required double currentHeading}) {
    return _calculateRfLinkUseCase.execute(
      tower: tower,
      clientLat: clientLat,
      clientLon: clientLon,
      currentHeading: currentHeading,
    );
  }

  Future<void> saveInstallationJob({
    required String clientName,
    required String notes,
    int? rsrpDbm,
    required double currentPitch,
    required double currentHeading,
  }) async {
    final telemetry = calculateRfLink(currentHeading: currentHeading);
    final String resolvedAddress = clientAddress.isNotEmpty
        ? clientAddress
        : '${clientLat.toStringAsFixed(4)}, ${clientLon.toStringAsFixed(4)}';
    final String resolvedClientName = clientName.trim().isEmpty ? 'Cliente AFR 5G' : clientName.trim();

    final job = InstallationJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      clientName: resolvedClientName,
      clientAddress: resolvedAddress,
      clientLat: clientLat,
      clientLon: clientLon,
      towerId: tower.id,
      towerCode: tower.code,
      towerAddress: tower.address,
      targetBearing: tower.azimuthBearing,
      distanceMeters: tower.distanceMeters,
      technologyBand: tower.has5Gn78 ? '5G n78 (3.5 GHz)' : '5G n28 (700 MHz)',
      rsrpDbm: rsrpDbm,
      notes: notes.trim(),
      createdAt: DateTime.now(),
      fsplDb: telemetry.fsplDb,
      fresnelRadiusMeters: telemetry.fresnelRadiusMeters,
      estimatedRsrpDbm: telemetry.estimatedRsrpDbm,
      downlinkEstimatedMbps: telemetry.estimatedDownlinkMbps,
      mechanicalTiltDeg: currentPitch,
      magneticDeclinationDeg: telemetry.magneticDeclinationDeg,
      gpsAccuracyMeters: _sensorsService.orientationNotifier.value.accuracy,
    );

    await _jobRepository.saveJob(job);
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _sensorSub?.cancel();
      _sensorsService.dispose();
      super.dispose();
    }
  }
}
