import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';

void main() {
  group('GeoCalculator Tests', () {
    test('Haversine distance calculation between Puerta del Sol and Gran Via 28', () {
      // Puerta del Sol, Madrid: 40.416775, -3.703790
      // Gran Via 28 (Telefónica Building): 40.420672, -3.701703
      final distance = GeoCalculator.calculateDistanceMeters(
        40.416775,
        -3.703790,
        40.420672,
        -3.701703,
      );

      // Distance should be approximately 465 meters
      expect(distance, greaterThan(400.0));
      expect(distance, lessThan(550.0));
      expect(GeoCalculator.formatDistance(distance), matches(r'^\d+\s*m$'));
    });

    test('Bearing calculation for cardinal and diagonal directions', () {
      // Due North: same lon, higher lat
      final northBearing = GeoCalculator.calculateBearing(40.0, 0.0, 41.0, 0.0);
      expect(northBearing, closeTo(0.0, 0.5));
      expect(GeoCalculator.bearingToCardinal(northBearing), equals('N'));

      // Due East: same lat, higher lon
      final eastBearing = GeoCalculator.calculateBearing(0.0, 0.0, 0.0, 1.0);
      expect(eastBearing, closeTo(90.0, 0.5));
      expect(GeoCalculator.bearingToCardinal(eastBearing), equals('E'));

      // Due South: same lon, lower lat
      final southBearing = GeoCalculator.calculateBearing(41.0, 0.0, 40.0, 0.0);
      expect(southBearing, closeTo(180.0, 0.5));
      expect(GeoCalculator.bearingToCardinal(southBearing), equals('S'));

      // Due West: same lat, lower lon
      final westBearing = GeoCalculator.calculateBearing(0.0, 1.0, 0.0, 0.0);
      expect(westBearing, closeTo(270.0, 0.5));
      expect(GeoCalculator.bearingToCardinal(westBearing), equals('W'));
    });

    test('Angular deviation and turn direction cues', () {
      // Facing 0° (North), target is 30° (NNE) -> Turn right +30°
      expect(GeoCalculator.calculateAngularDeviation(0.0, 30.0), closeTo(30.0, 0.01));

      // Facing 0° (North), target is 330° (NNW) -> Turn left -30°
      expect(GeoCalculator.calculateAngularDeviation(0.0, 330.0), closeTo(-30.0, 0.01));

      // Facing 350°, target is 10° -> Turn right +20° across boundary
      expect(GeoCalculator.calculateAngularDeviation(350.0, 10.0), closeTo(20.0, 0.01));

      // Facing 10°, target is 350° -> Turn left -20° across boundary
      expect(GeoCalculator.calculateAngularDeviation(10.0, 350.0), closeTo(-20.0, 0.01));

      // Perfect alignment
      expect(GeoCalculator.calculateAngularDeviation(142.5, 142.5), equals(0.0));
    });

    test('Elevation tilt angle calculation', () {
      // 1000m distance, 50m height difference
      final tilt = GeoCalculator.calculateElevationTilt(1000.0, 10.0, 60.0);
      expect(tilt, greaterThan(0.0));
      expect(tilt, closeTo(2.86, 0.1));
    });

    test('Bounding box calculation for 5km radius around Madrid', () {
      final bbox = GeoCalculator.calculateBbox(40.4168, -3.7038, 5.0);
      // bbox format: [minLon, minLat, maxLon, maxLat]
      expect(bbox.length, equals(4));
      expect(bbox[0], lessThan(bbox[2])); // minLon < maxLon
      expect(bbox[1], lessThan(bbox[3])); // minLat < maxLat
      expect(bbox[1], lessThan(40.4168));
      expect(bbox[3], greaterThan(40.4168));
    });
  });
}
