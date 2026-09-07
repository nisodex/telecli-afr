import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/core/utils/rf_calculator.dart';

void main() {
  group('RfCalculator Tests', () {
    test('FSPL calculation at 1000m for 3500 MHz (n78) and 700 MHz (n28)', () {
      final fsplN78 = RfCalculator.calculateFspl(1000, RfCalculator.freq5Gn78Mhz);
      // 20*log10(1000) = 60; 20*log10(3500) = 70.88; 60 + 70.88 - 27.55 = 103.33 dB
      expect(fsplN78, closeTo(103.33, 0.2));

      final fsplN28 = RfCalculator.calculateFspl(1000, RfCalculator.freq5Gn28Mhz);
      // 20*log10(1000) = 60; 20*log10(700) = 56.90; 60 + 56.90 - 27.55 = 89.35 dB
      expect(fsplN28, closeTo(89.35, 0.2));
    });

    test('1st Fresnel Zone Radius and 60% clearance', () {
      // At 1000m and 3500 MHz: sqrt((75 * 1000) / 3500) = sqrt(21.428) = 4.63m
      final r1 = RfCalculator.calculateFresnelRadius(1000, RfCalculator.freq5Gn78Mhz);
      expect(r1, closeTo(4.63, 0.1));

      final clearance60 = RfCalculator.calculateFresnel60PercentClearance(1000, RfCalculator.freq5Gn78Mhz);
      expect(clearance60, closeTo(2.78, 0.1));
    });

    test('RSRP Estimation for 300m and 2000m in n78', () {
      final rsrp300m = RfCalculator.estimateRsrp(distanceMeters: 300, isN78: true);
      // At 300m in direct LOS, signal should be very strong (between -55 and -80 dBm)
      expect(rsrp300m, lessThan(-55.0));
      expect(rsrp300m, greaterThan(-80.0));

      final rsrp2000m = RfCalculator.estimateRsrp(distanceMeters: 2000, isN78: true);
      // At 2km in 3.5 GHz, signal is weaker
      expect(rsrp2000m, lessThan(rsrp300m));
    });

    test('Antenna Half Power Beamwidth evaluation', () {
      // In n78 (3.5 GHz), tolerance is +-15°
      expect(RfCalculator.isInsideMainBeam(angularDeviation: 10.0, isN78: true), isTrue);
      expect(RfCalculator.isInsideMainBeam(angularDeviation: -14.5, isN78: true), isTrue);
      expect(RfCalculator.isInsideMainBeam(angularDeviation: 18.0, isN78: true), isFalse);

      // In n28 (700 MHz), tolerance is broader (+-35°)
      expect(RfCalculator.isInsideMainBeam(angularDeviation: 25.0, isN78: false), isTrue);
      expect(RfCalculator.isInsideMainBeam(angularDeviation: 40.0, isN78: false), isFalse);
    });

    test('Magnetic Declination estimation for Madrid', () {
      final dec = RfCalculator.estimateMagneticDeclination(40.4167, -3.7037);
      // Madrid declination is around -0.5°
      expect(dec, closeTo(-0.5, 0.2));
    });

    test('Downlink throughput estimation', () {
      final highSpeed = RfCalculator.estimateDownlinkThroughput(rsrpDbm: -75.0, isN78: true);
      expect(highSpeed, greaterThanOrEqualTo(900));

      final lowSpeed = RfCalculator.estimateDownlinkThroughput(rsrpDbm: -110.0, isN78: true);
      expect(lowSpeed, lessThan(100));
    });
  });
}
