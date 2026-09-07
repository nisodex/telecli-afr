import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/repositories/location_repository.dart';
import 'package:telecli_afr/data/repositories/tower_repository.dart';
import 'package:telecli_afr/ui/view_models/tower_list_view_model.dart';

class MockLocationRepo implements LocationRepository {
  @override
  Future<Position> getCurrentPosition() async => throw UnimplementedError();

  @override
  Future<String> reverseGeocode(double lat, double lon) async => 'Madrid';
}

class MockTowerRepo implements TowerRepository {
  @override
  Future<List<TowerModel>> getTowersAroundLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    bool onlyMovistar = true,
  }) async {
    return [
      TowerModel(
        id: 't-1',
        code: 'MAD-N78',
        operator: 'Movistar',
        address: 'Gran Via 28',
        latitude: 40.42,
        longitude: -3.70,
        distanceMeters: 100,
        azimuthBearing: 0,
        elevationTilt: 0,
        has5Gn78: true,
        has5Gn28: false,
        has4G: true,
        isMovistar: true,
      ),
      TowerModel(
        id: 't-2',
        code: 'MAD-N28',
        operator: 'Movistar',
        address: 'Alcala 1',
        latitude: 40.41,
        longitude: -3.70,
        distanceMeters: 200,
        azimuthBearing: 90,
        elevationTilt: 0,
        has5Gn78: false,
        has5Gn28: true,
        has4G: true,
        isMovistar: true,
      ),
      TowerModel(
        id: 't-3',
        code: 'ORA-01',
        operator: 'Orange',
        address: 'Paseo del Prado',
        latitude: 40.41,
        longitude: -3.69,
        distanceMeters: 400,
        azimuthBearing: 180,
        elevationTilt: 0,
        has5Gn78: true,
        has5Gn28: false,
        has4G: true,
        isMovistar: false,
      ),
    ];
  }

  @override
  Future<TowerModel?> getTowerById(String id) async => null;
}

void main() {
  group('TowerListViewModel Tests', () {
    test('Filters towers correctly by 5G n78, 5G n28, and search query', () async {
      final viewModel = TowerListViewModel(
        towerRepository: MockTowerRepo(),
        locationRepository: MockLocationRepo(),
      );

      await viewModel.loadTowersForLocation(clientLat: 40.4, clientLon: -3.7);

      // Default filter is '5G n78' (only Movistar with n78)
      expect(viewModel.filteredTowers.length, equals(1));
      expect(viewModel.filteredTowers.first.code, equals('MAD-N78'));

      // Switch filter to '5G n28'
      viewModel.setFilter('5G n28');
      expect(viewModel.filteredTowers.length, equals(1));
      expect(viewModel.filteredTowers.first.code, equals('MAD-N28'));

      // Switch filter to 'Todas' (includes Orange)
      viewModel.setFilter('Todas');
      expect(viewModel.filteredTowers.length, equals(3));

      // Search query
      viewModel.setSearchQuery('Gran Via');
      expect(viewModel.filteredTowers.length, equals(1));
      expect(viewModel.filteredTowers.first.address, contains('Gran Via'));
    });
  });
}
