import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/domain/use_cases/find_optimal_5g_tower_use_case.dart';

void main() {
  group('FindOptimal5gTowerUseCase Tests', () {
    const useCase = FindOptimal5gTowerUseCase();

    test('Returns null if list is empty', () {
      expect(useCase.execute([]), isNull);
    });

    test('Prioritizes closest 5G n78 tower over 5G n28 and 4G', () {
      final towers = <TowerModel>[
        TowerModel(
          id: '1',
          code: 'MAD-01',
          operator: 'Movistar',
          address: 'Torre 4G',
          latitude: 40.4,
          longitude: -3.7,
          distanceMeters: 200,
          azimuthBearing: 90,
          elevationTilt: 0,
          has5Gn78: false,
          has5Gn28: false,
          has4G: true,
          isMovistar: true,
        ),
        TowerModel(
          id: '2',
          code: 'MAD-02',
          operator: 'Movistar',
          address: 'Torre 5G n28',
          latitude: 40.41,
          longitude: -3.71,
          distanceMeters: 300,
          azimuthBearing: 120,
          elevationTilt: 0,
          has5Gn78: false,
          has5Gn28: true,
          has4G: true,
          isMovistar: true,
        ),
        TowerModel(
          id: '3',
          code: 'MAD-03',
          operator: 'Movistar',
          address: 'Torre 5G n78',
          latitude: 40.42,
          longitude: -3.72,
          distanceMeters: 450,
          azimuthBearing: 180,
          elevationTilt: 0,
          has5Gn78: true,
          has5Gn28: true,
          has4G: true,
          isMovistar: true,
        ),
      ];

      final optimal = useCase.execute(towers);
      expect(optimal, isNotNull);
      expect(optimal!.id, equals('3'));
      expect(optimal.has5Gn78, isTrue);
    });

    test('Falls back to closest 5G n28 if no n78 available', () {
      final towers = <TowerModel>[
        TowerModel(
          id: '1',
          code: 'MAD-01',
          operator: 'Movistar',
          address: 'Torre 4G',
          latitude: 40.4,
          longitude: -3.7,
          distanceMeters: 200,
          azimuthBearing: 90,
          elevationTilt: 0,
          has5Gn78: false,
          has5Gn28: false,
          has4G: true,
          isMovistar: true,
        ),
        TowerModel(
          id: '2',
          code: 'MAD-02',
          operator: 'Movistar',
          address: 'Torre 5G n28',
          latitude: 40.41,
          longitude: -3.71,
          distanceMeters: 300,
          azimuthBearing: 120,
          elevationTilt: 0,
          has5Gn78: false,
          has5Gn28: true,
          has4G: true,
          isMovistar: true,
        ),
      ];

      final optimal = useCase.execute(towers);
      expect(optimal, isNotNull);
      expect(optimal!.id, equals('2'));
      expect(optimal.has5Gn28, isTrue);
    });
  });
}
