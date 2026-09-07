import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/data/services/province_manager_service.dart';

void main() {
  group('ProvinceManagerService Unit Tests', () {
    test('Contains standard Spanish operational provinces', () {
      expect(ProvinceManagerService.provinces, isNotEmpty);
      final madrid = ProvinceManagerService.provinces.firstWhere((p) => p.code == 'MAD');
      expect(madrid.name, equals('Madrid'));
      expect(madrid.bbox.length, equals(4));

      // Madrid longitude is west of Prime Meridian (negative)
      expect(madrid.bbox[0], lessThan(0.0)); // minLon
      expect(madrid.bbox[2], lessThan(0.0)); // maxLon

      // Madrid latitude is roughly between 39.8° and 41.2°
      expect(madrid.bbox[1], greaterThan(39.0)); // minLat
      expect(madrid.bbox[3], lessThan(42.0));    // maxLat
    });

    test('Bounding boxes are geometrically valid for all registered provinces', () {
      for (final province in ProvinceManagerService.provinces) {
        final minLon = province.bbox[0];
        final minLat = province.bbox[1];
        final maxLon = province.bbox[2];
        final maxLat = province.bbox[3];

        expect(minLon, lessThan(maxLon), reason: 'minLon < maxLon for ${province.name}');
        expect(minLat, lessThan(maxLat), reason: 'minLat < maxLat for ${province.name}');
      }
    });
  });
}
