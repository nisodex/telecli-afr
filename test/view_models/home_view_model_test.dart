import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/repositories/location_repository.dart';
import 'package:telecli_afr/data/repositories/tower_repository.dart';
import 'package:telecli_afr/ui/view_models/home_view_model.dart';

class FakeLocationRepository implements LocationRepository {
  @override
  Future<Position> getCurrentPosition() async {
    return Position(
      longitude: -3.3600,
      latitude: 40.4800,
      timestamp: DateTime.now(),
      accuracy: 3.5,
      altitude: 650.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  @override
  Future<String> reverseGeocode(double lat, double lon) async {
    return 'Alcalá de Henares, Madrid';
  }
}

class FakeTowerRepository implements TowerRepository {
  @override
  Future<List<TowerModel>> getTowersAroundLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    bool onlyMovistar = true,
  }) async {
    return [
      TowerModel(
        id: 'fake-1',
        code: 'ALC-01',
        operator: 'Movistar',
        address: 'Calle Mayor 10, Alcalá',
        latitude: 40.4810,
        longitude: -3.3610,
        distanceMeters: 250,
        azimuthBearing: 310,
        elevationTilt: 0,
        has5Gn78: true,
        has5Gn28: true,
        has4G: true,
        isMovistar: true,
      ),
    ];
  }

  @override
  Future<TowerModel?> getTowerById(String id) async => null;
}

void main() {
  group('HomeViewModel Tests', () {
    test('initLocationAndTowers updates position, address, and selects optimal tower', () async {
      final viewModel = HomeViewModel(
        locationRepository: FakeLocationRepository(),
        towerRepository: FakeTowerRepository(),
      );

      expect(viewModel.isLoadingGps, isTrue);
      expect(viewModel.isLoadingTowers, isTrue);

      await viewModel.initLocationAndTowers();

      expect(viewModel.isLoadingGps, isFalse);
      expect(viewModel.isLoadingTowers, isFalse);
      expect(viewModel.address, equals('Alcalá de Henares, Madrid'));
      expect(viewModel.lat, equals(40.4800));
      expect(viewModel.lon, equals(-3.3600));
      expect(viewModel.towers.length, equals(1));
      expect(viewModel.best5gTower, isNotNull);
      expect(viewModel.best5gTower!.has5Gn78, isTrue);
    });
  });
}
