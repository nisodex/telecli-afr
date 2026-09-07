import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/repositories/location_repository.dart';
import 'package:telecli_afr/data/repositories/tower_repository.dart';
import 'package:telecli_afr/ui/features/map/view_models/map_view_model.dart';

class FakeLocationRepo implements LocationRepository {
  double lat = 40.4168;
  double lon = -3.7038;

  @override
  Future<Position> getCurrentPosition() async {
    return Position(
      longitude: lon,
      latitude: lat,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 655.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  @override
  Future<String> reverseGeocode(double lat, double lon) async {
    return 'Madrid Centro';
  }
}

class FakeTowerRepo implements TowerRepository {
  List<TowerModel> simulatedTowers = [];
  double lastRequestedRadius = 5.0;
  bool lastRequestedMovistar = true;

  @override
  Future<List<TowerModel>> getTowersAroundLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    bool onlyMovistar = true,
  }) async {
    lastRequestedRadius = radiusKm;
    lastRequestedMovistar = onlyMovistar;
    return simulatedTowers;
  }

  @override
  Future<TowerModel?> getTowerById(String id) async {
    try {
      return simulatedTowers.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TowerModel> getTowerTechnicalDetails(TowerModel tower) async => tower;
}

void main() {
  group('MapViewModel Tests', () {
    late FakeLocationRepo fakeLocationRepo;
    late FakeTowerRepo fakeTowerRepo;
    late TowerModel testTower1;
    late TowerModel testTower2;

    setUp(() {
      fakeLocationRepo = FakeLocationRepo();
      fakeTowerRepo = FakeTowerRepo();

      testTower1 = TowerModel(
        id: 't-1',
        code: 'MAD-01',
        operator: 'Movistar',
        address: 'Gran Vía 28',
        latitude: 40.4200,
        longitude: -3.7040,
        distanceMeters: 350,
        azimuthBearing: 45,
        elevationTilt: 1.2,
        has5Gn78: true,
        isMovistar: true,
      );

      testTower2 = TowerModel(
        id: 't-2',
        code: 'MAD-02',
        operator: 'Movistar',
        address: 'Puerta del Sol 1',
        latitude: 40.4170,
        longitude: -3.7030,
        distanceMeters: 120,
        azimuthBearing: 180,
        elevationTilt: 0.5,
        has4G: true,
        isMovistar: true,
      );

      fakeTowerRepo.simulatedTowers = [testTower1, testTower2];
    });

    test('initializes with provided coordinates and selects first tower', () async {
      final viewModel = MapViewModel(
        locationRepository: fakeLocationRepo,
        towerRepository: fakeTowerRepo,
      );

      viewModel.initialize(
        initialLat: 40.4168,
        initialLon: -3.7038,
        initialTowers: [testTower1, testTower2],
        initialSelectedTower: testTower2,
      );

      expect(viewModel.clientLat, equals(40.4168));
      expect(viewModel.clientLon, equals(-3.7038));
      expect(viewModel.towers.length, equals(2));
      expect(viewModel.selectedTower?.id, equals('t-2'));
      expect(viewModel.isLoading, isFalse);
    });

    test('loads towers around client location and reverse geocodes address', () async {
      final viewModel = MapViewModel(
        locationRepository: fakeLocationRepo,
        towerRepository: fakeTowerRepo,
      );

      viewModel.initialize(
        initialLat: 40.4168,
        initialLon: -3.7038,
      );

      await viewModel.loadTowers();

      expect(viewModel.towers.length, equals(2));
      expect(viewModel.selectedTower?.id, equals('t-1'));
      expect(viewModel.addressText, equals('Madrid Centro'));
      expect(viewModel.isLoading, isFalse);
    });

    test('setSearchRadius triggers reload with updated radius', () async {
      final viewModel = MapViewModel(
        locationRepository: fakeLocationRepo,
        towerRepository: fakeTowerRepo,
      );

      viewModel.initialize(initialLat: 40.4168, initialLon: -3.7038);
      viewModel.setSearchRadius(10.0);

      expect(viewModel.searchRadiusKm, equals(10.0));
      expect(fakeTowerRepo.lastRequestedRadius, equals(10.0));
    });

    test('toggleOnlyMovistar toggles filter and updates repository query', () async {
      final viewModel = MapViewModel(
        locationRepository: fakeLocationRepo,
        towerRepository: fakeTowerRepo,
      );

      viewModel.initialize(initialLat: 40.4168, initialLon: -3.7038);
      expect(viewModel.onlyMovistar, isTrue);

      viewModel.toggleOnlyMovistar();
      expect(viewModel.onlyMovistar, isFalse);
      expect(fakeTowerRepo.lastRequestedMovistar, isFalse);
    });

    test('selectTower changes active tower selection', () {
      final viewModel = MapViewModel(
        locationRepository: fakeLocationRepo,
        towerRepository: fakeTowerRepo,
      );

      viewModel.initialize(
        initialLat: 40.4168,
        initialLon: -3.7038,
        initialTowers: [testTower1, testTower2],
      );

      expect(viewModel.selectedTower?.id, equals('t-1'));

      viewModel.selectTower(testTower2);
      expect(viewModel.selectedTower?.id, equals('t-2'));
    });

    test('recenterGps updates coordinates from LocationRepository', () async {
      final viewModel = MapViewModel(
        locationRepository: fakeLocationRepo,
        towerRepository: fakeTowerRepo,
      );

      viewModel.initialize(initialLat: 40.0, initialLon: -3.0);
      fakeLocationRepo.lat = 40.4500;
      fakeLocationRepo.lon = -3.6900;

      await viewModel.recenterGps();

      expect(viewModel.clientLat, equals(40.4500));
      expect(viewModel.clientLon, equals(-3.6900));
    });
  });
}
