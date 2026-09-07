import '../../core/utils/rf_calculator.dart';
import '../../data/models/tower_model.dart';

/// Output model containing calculated RF engineering link telemetry.
class RfLinkTelemetry {
  final double fsplDb;
  final double fresnelRadiusMeters;
  final double clearance60PercentMeters;
  final double estimatedRsrpDbm;
  final int estimatedDownlinkMbps;
  final bool isInsideMainBeam;
  final double magneticDeclinationDeg;

  const RfLinkTelemetry({
    required this.fsplDb,
    required this.fresnelRadiusMeters,
    required this.clearance60PercentMeters,
    required this.estimatedRsrpDbm,
    required this.estimatedDownlinkMbps,
    required this.isInsideMainBeam,
    required this.magneticDeclinationDeg,
  });
}

/// Domain Use Case calculating complete RF link parameters and propagation physics.
class CalculateRfLinkUseCase {
  const CalculateRfLinkUseCase();

  RfLinkTelemetry execute({
    required TowerModel tower,
    required double clientLat,
    required double clientLon,
    required double currentHeading,
    double customAntennaGainDbi = 11.5,
    double cableLossDb = 0.5,
  }) {
    final double dist = tower.distanceMeters;
    final bool isN78 = tower.has5Gn78;
    final double freqMhz = isN78 ? RfCalculator.freq5Gn78Mhz : RfCalculator.freq5Gn28Mhz;

    final double fsplDb = RfCalculator.calculateFspl(dist, freqMhz);
    final double fresnelR1 = RfCalculator.calculateFresnelRadius(dist, freqMhz);
    final double clearance60 = RfCalculator.calculateFresnel60PercentClearance(dist, freqMhz);

    final double estimatedRsrp = RfCalculator.estimateRsrp(
      distanceMeters: dist,
      isN78: isN78,
      customAntennaGainDbi: customAntennaGainDbi,
      cableLossDb: cableLossDb,
    );

    final int estMbps = RfCalculator.estimateDownlinkThroughput(
      rsrpDbm: estimatedRsrp,
      isN78: isN78,
    );

    final double angularDev = (currentHeading - tower.azimuthBearing + 540.0) % 360.0 - 180.0;
    final bool inMainBeam = RfCalculator.isInsideMainBeam(
      angularDeviation: angularDev,
      isN78: isN78,
    );

    final double declination = RfCalculator.estimateMagneticDeclination(clientLat, clientLon);

    return RfLinkTelemetry(
      fsplDb: fsplDb,
      fresnelRadiusMeters: fresnelR1,
      clearance60PercentMeters: clearance60,
      estimatedRsrpDbm: estimatedRsrp,
      estimatedDownlinkMbps: estMbps,
      isInsideMainBeam: inMainBeam,
      magneticDeclinationDeg: declination,
    );
  }
}
