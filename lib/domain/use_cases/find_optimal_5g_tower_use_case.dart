import '../../data/models/tower_model.dart';

/// Domain Use Case for selecting the optimal cell tower for Movistar AFR 5G installation.
class FindOptimal5gTowerUseCase {
  const FindOptimal5gTowerUseCase();

  /// Evaluates a list of cell towers and selects the best candidate according to:
  /// 1. Movistar 5G n78 (3.5 GHz) - High Speed FWA priority
  /// 2. Movistar 5G n28 (700 MHz) - High penetration rural fallback
  /// 3. Nearest available Movistar station
  TowerModel? execute(List<TowerModel> towers) {
    if (towers.isEmpty) return null;

    final movistarTowers = towers.where((t) => t.isMovistar).toList();
    if (movistarTowers.isEmpty) {
      // Fallback to closest of any available provider if no Movistar towers found
      return towers.first;
    }

    // Priority 1: Closest Movistar 5G n78
    final n78Towers = movistarTowers.where((t) => t.has5Gn78).toList();
    if (n78Towers.isNotEmpty) {
      n78Towers.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return n78Towers.first;
    }

    // Priority 2: Closest Movistar 5G n28
    final n28Towers = movistarTowers.where((t) => t.has5Gn28).toList();
    if (n28Towers.isNotEmpty) {
      n28Towers.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return n28Towers.first;
    }

    // Priority 3: Closest Movistar tower
    movistarTowers.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return movistarTowers.first;
  }
}
