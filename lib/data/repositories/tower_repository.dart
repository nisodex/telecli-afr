import '../models/tower_model.dart';
import '../services/minetur_service.dart';

/// Abstract contract for Cell Tower data access.
abstract class TowerRepository {
  Future<List<TowerModel>> getTowersAroundLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    bool onlyMovistar = true,
  });

  Future<TowerModel?> getTowerById(String id);
}

/// Production implementation consuming MineturService and caching stations.
class TowerRepositoryImpl implements TowerRepository {
  final MineturService _mineturService;
  List<TowerModel> _cache = [];

  TowerRepositoryImpl({MineturService? mineturService})
      : _mineturService = mineturService ?? MineturService();

  @override
  Future<List<TowerModel>> getTowersAroundLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    bool onlyMovistar = true,
  }) async {
    final towers = await _mineturService.fetchTowersAroundLocation(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
      onlyMovistar: onlyMovistar,
    );
    _cache = towers;
    return towers;
  }

  @override
  Future<TowerModel?> getTowerById(String id) async {
    if (_cache.isNotEmpty) {
      try {
        return _cache.firstWhere((t) => t.id == id);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
