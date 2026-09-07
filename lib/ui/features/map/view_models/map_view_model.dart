import 'package:flutter/foundation.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/repositories/location_repository.dart';
import 'package:telecli_afr/data/repositories/tower_repository.dart';
import 'package:telecli_afr/data/services/location_service.dart';

/// MVVM ViewModel managing Map Screen state, tower geospatial discovery, filters, and client location.
class MapViewModel extends ChangeNotifier {
  final TowerRepository _towerRepository;
  final LocationRepository _locationRepository;

  MapViewModel({
    TowerRepository? towerRepository,
    LocationRepository? locationRepository,
  })  : _towerRepository = towerRepository ?? TowerRepositoryImpl(),
        _locationRepository = locationRepository ?? LocationRepositoryImpl();

  double _clientLat = LocationService.defaultLat;
  double get clientLat => _clientLat;

  double _clientLon = LocationService.defaultLon;
  double get clientLon => _clientLon;

  List<TowerModel> _towers = [];
  List<TowerModel> get towers => List.unmodifiable(_towers);

  TowerModel? _selectedTower;
  TowerModel? get selectedTower => _selectedTower;

  double _searchRadiusKm = 5.0;
  double get searchRadiusKm => _searchRadiusKm;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _onlyMovistar = true;
  bool get onlyMovistar => _onlyMovistar;

  String _addressText = '';
  String get addressText => _addressText;

  void initialize({
    required double initialLat,
    required double initialLon,
    List<TowerModel> initialTowers = const [],
    TowerModel? initialSelectedTower,
  }) {
    final cachedPos = LocationService.lastPosition;
    if ((initialLat == LocationService.defaultLat) && cachedPos != null) {
      _clientLat = cachedPos.latitude;
      _clientLon = cachedPos.longitude;
    } else {
      _clientLat = initialLat;
      _clientLon = initialLon;
    }

    _towers = List.from(initialTowers);
    _selectedTower = initialSelectedTower ?? (_towers.isNotEmpty ? _towers.first : null);

    if (_towers.isEmpty) {
      loadTowers();
    }
  }

  void updateLocationAndTowers({
    required double lat,
    required double lon,
    List<TowerModel>? towers,
    TowerModel? selectedTower,
  }) {
    final bool locationChanged = _clientLat != lat || _clientLon != lon;
    _clientLat = lat;
    _clientLon = lon;

    if (towers != null && towers.isNotEmpty) {
      _towers = List.from(towers);
    }

    if (selectedTower != null) {
      _selectedTower = selectedTower;
    } else if (_selectedTower == null && _towers.isNotEmpty) {
      _selectedTower = _towers.first;
    }

    notifyListeners();

    if (_towers.isEmpty && locationChanged) {
      loadTowers();
    }
  }

  Future<void> loadTowers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final fetched = await _towerRepository.getTowersAroundLocation(
        lat: _clientLat,
        lon: _clientLon,
        radiusKm: _searchRadiusKm,
        onlyMovistar: _onlyMovistar,
      );

      _addressText = await _locationRepository.reverseGeocode(_clientLat, _clientLon);
      _towers = fetched;

      if (_selectedTower != null) {
        _selectedTower = _towers.firstWhere(
          (t) => t.id == _selectedTower!.id,
          orElse: () => _towers.isNotEmpty ? _towers.first : _selectedTower!,
        );
      } else if (_towers.isNotEmpty) {
        _selectedTower = _towers.first;
      }
    } catch (e) {
      debugPrint('[MapViewModel] Error loading towers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> recenterGps() async {
    _isLoading = true;
    notifyListeners();

    try {
      final pos = await _locationRepository.getCurrentPosition();
      _clientLat = pos.latitude;
      _clientLon = pos.longitude;
      await loadTowers();
    } catch (e) {
      debugPrint('[MapViewModel] Recenter GPS error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchRadius(double radiusKm) {
    if (_searchRadiusKm == radiusKm) return;
    _searchRadiusKm = radiusKm;
    loadTowers();
  }

  void toggleOnlyMovistar() {
    _onlyMovistar = !_onlyMovistar;
    loadTowers();
  }

  void selectTower(TowerModel tower) {
    _selectedTower = tower;
    notifyListeners();
  }
}
