import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/repositories/tower_repository.dart';
import 'package:telecli_afr/ui/features/towers/view_models/tower_detail_view_model.dart';

class FakeDetailTowerRepo implements TowerRepository {
  bool shouldFail = false;
  TowerModel? detailToReturn;

  @override
  Future<List<TowerModel>> getTowersAroundLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    bool onlyMovistar = true,
  }) async => [];

  @override
  Future<TowerModel?> getTowerById(String id) async => null;

  @override
  Future<TowerModel> getTowerTechnicalDetails(TowerModel tower) async {
    if (shouldFail) {
      throw Exception('Minetur VCTEL server error');
    }
    return detailToReturn ??
        tower.copyWith(
          sectorAzimuths: [45.0, 165.0, 285.0],
          bands: ['n78', 'n28', 'B1', 'B3', 'B7', 'B20'],
        );
  }
}

void main() {
  group('TowerDetailViewModel Tests', () {
    late TowerModel baseTower;
    late FakeDetailTowerRepo fakeRepo;

    setUp(() {
      baseTower = TowerModel(
        id: 'tower-detail-1',
        code: 'MAD-5G-88',
        operator: 'Movistar',
        address: 'Paseo de la Castellana 100',
        latitude: 40.4400,
        longitude: -3.6900,
        distanceMeters: 500,
        azimuthBearing: 120,
        elevationTilt: 2.0,
        has5Gn78: true,
        isMovistar: true,
      );
      fakeRepo = FakeDetailTowerRepo();
    });

    test('initializes with base tower and idle state', () {
      final viewModel = TowerDetailViewModel(
        initialTower: baseTower,
        towerRepository: fakeRepo,
      );

      expect(viewModel.tower.id, equals('tower-detail-1'));
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('fetchTechnicalDetails enriches tower data via repository', () async {
      final viewModel = TowerDetailViewModel(
        initialTower: baseTower,
        towerRepository: fakeRepo,
      );

      expect(viewModel.tower.sectorAzimuths, isEmpty);

      final future = viewModel.fetchTechnicalDetails();
      expect(viewModel.isLoading, isTrue);

      await future;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.tower.sectorAzimuths, equals([45.0, 165.0, 285.0]));
      expect(viewModel.tower.bands.length, equals(6));
    });

    test('fetchTechnicalDetails captures error and stops loading when repository fails', () async {
      fakeRepo.shouldFail = true;

      final viewModel = TowerDetailViewModel(
        initialTower: baseTower,
        towerRepository: fakeRepo,
      );

      await viewModel.fetchTechnicalDetails();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, contains('Minetur VCTEL server error'));
      expect(viewModel.tower.sectorAzimuths, isEmpty);
    });
  });
}
