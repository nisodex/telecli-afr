import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/tower_model.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/tower_repository.dart';
import '../../data/services/location_service.dart';
import '../../domain/use_cases/find_optimal_5g_tower_use_case.dart';

/// MVVM ViewModel managing Home Screen state, GPS localization, and optimal tower discovery.
class HomeViewModel extends ChangeNotifier {
  final LocationRepository _locationRepository;
  final TowerRepository _towerRepository;
  final FindOptimal5gTowerUseCase _findOptimalTowerUseCase;

  HomeViewModel({
    LocationRepository? locationRepository,
    TowerRepository? towerRepository,
    FindOptimal5gTowerUseCase? findOptimalTowerUseCase,
  })  : _locationRepository = locationRepository ?? LocationRepositoryImpl(),
        _towerRepository = towerRepository ?? TowerRepositoryImpl(),
        _findOptimalTowerUseCase = findOptimalTowerUseCase ?? const FindOptimal5gTowerUseCase();

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  double _lat = LocationService.defaultLat;
  double get lat => _lat;

  double _lon = LocationService.defaultLon;
  double get lon => _lon;

  String _address = 'Localizando cliente...';
  String get address => _address;

  bool _isLoadingGps = true;
  bool get isLoadingGps => _isLoadingGps;

  bool _isLoadingTowers = true;
  bool get isLoadingTowers => _isLoadingTowers;

  List<TowerModel> _towers = [];
  List<TowerModel> get towers => List.unmodifiable(_towers);

  TowerModel? _best5gTower;
  TowerModel? get best5gTower => _best5gTower;

  Future<void> initLocationAndTowers() async {
    _isLoadingGps = true;
    _isLoadingTowers = true;
    notifyListeners();

    try {
      final pos = await _locationRepository.getCurrentPosition();
      _currentPosition = pos;
      _lat = pos.latitude;
      _lon = pos.longitude;
      _address = await _locationRepository.reverseGeocode(_lat, _lon);
    } catch (e) {
      debugPrint('[HomeViewModel] GPS init error: $e');
      _address = 'Madrid Centro (Referencia)';
    } finally {
      _isLoadingGps = false;
      notifyListeners();
      await loadSurroundingTowers();
    }
  }

  Future<void> loadSurroundingTowers() async {
    _isLoadingTowers = true;
    notifyListeners();

    try {
      final fetched = await _towerRepository.getTowersAroundLocation(
        lat: _lat,
        lon: _lon,
        radiusKm: 5.0,
        onlyMovistar: true,
      );
      _towers = fetched;
      _best5gTower = _findOptimalTowerUseCase.execute(fetched);
    } catch (e) {
      debugPrint('[HomeViewModel] Towers fetch error: $e');
    } finally {
      _isLoadingTowers = false;
      notifyListeners();
    }
  }
}
