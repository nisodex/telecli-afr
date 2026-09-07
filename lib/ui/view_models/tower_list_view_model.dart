import 'package:flutter/foundation.dart';
import '../../data/models/tower_model.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/tower_repository.dart';

/// MVVM ViewModel managing Tower List search, filtration, and proximity sorting.
class TowerListViewModel extends ChangeNotifier {
  final TowerRepository _towerRepository;
  final LocationRepository _locationRepository;

  TowerListViewModel({
    TowerRepository? towerRepository,
    LocationRepository? locationRepository,
  })  : _towerRepository = towerRepository ?? TowerRepositoryImpl(),
        _locationRepository = locationRepository ?? LocationRepositoryImpl();

  List<TowerModel> _allTowers = [];
  List<TowerModel> _filteredTowers = [];
  List<TowerModel> get filteredTowers => List.unmodifiable(_filteredTowers);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _selectedFilter = '5G n78';
  String get selectedFilter => _selectedFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _addressText = '';
  String get addressText => _addressText;

  void initializeWithTowers(List<TowerModel> initialTowers) {
    _allTowers = List.from(initialTowers);
    _applyFilter();
  }

  Future<void> loadTowersForLocation({
    required double clientLat,
    required double clientLon,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _addressText = await _locationRepository.reverseGeocode(clientLat, clientLon);
      final towers = await _towerRepository.getTowersAroundLocation(
        lat: clientLat,
        lon: clientLon,
        radiusKm: 10.0,
        onlyMovistar: false,
      );
      _allTowers = towers;
      _applyFilter();
    } catch (e) {
      debugPrint('[TowerListViewModel] loadTowers error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    _applyFilter();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    _filteredTowers = _allTowers.where((t) {
      // Text search
      if (_searchQuery.isNotEmpty) {
        final matches = t.address.toLowerCase().contains(_searchQuery) ||
            t.code.toLowerCase().contains(_searchQuery) ||
            t.operator.toLowerCase().contains(_searchQuery);
        if (!matches) return false;
      }

      // Technology filter
      switch (_selectedFilter) {
        case '5G n78':
          return t.isMovistar && t.has5Gn78;
        case '5G n28':
          return t.isMovistar && t.has5Gn28;
        case '4G LTE':
          return t.isMovistar && t.has4G;
        case 'Movistar':
          return t.isMovistar;
        case 'Todas':
        default:
          return true;
      }
    }).toList();
  }
}
