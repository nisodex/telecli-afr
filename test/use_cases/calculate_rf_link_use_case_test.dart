import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/domain/use_cases/calculate_rf_link_use_case.dart';

void main() {
  group('CalculateRfLinkUseCase Tests', () {
    const useCase = CalculateRfLinkUseCase();

    final towerN78 = TowerModel(
      id: 't-1',
      code: 'EST-3500',
      operator: 'Movistar',
      address: 'Calle Mayor 1',
      latitude: 40.4168,
      longitude: -3.7038,
      distanceMeters: 500,
      azimuthBearing: 120,
      elevationTilt: -2.5,
      has5Gn78: true,
      has5Gn28: true,
      has4G: true,
      isMovistar: true,
    );

    test('Calculates complete RF link telemetry for 5G n78 station', () {
      final telemetry = useCase.execute(
        tower: towerN78,
        clientLat: 40.4160,
        clientLon: -3.7030,
        currentHeading: 122.0, // Aligned within 2°
      );

      expect(telemetry.fsplDb, greaterThan(90.0));
      expect(telemetry.fresnelRadiusMeters, greaterThan(3.0));
      expect(telemetry.clearance60PercentMeters, greaterThan(1.5));
      expect(telemetry.estimatedRsrpDbm, greaterThan(-95.0));
      expect(telemetry.estimatedDownlinkMbps, greaterThan(200));
      expect(telemetry.isInsideMainBeam, isTrue);
    });

    test('Detects off-main-beam alignment when heading deviates significantly', () {
      final telemetry = useCase.execute(
        tower: towerN78,
        clientLat: 40.4160,
        clientLon: -3.7030,
        currentHeading: 200.0, // 80° deviation -> outside HPBW
      );

      expect(telemetry.isInsideMainBeam, isFalse);
    });
  });
}
