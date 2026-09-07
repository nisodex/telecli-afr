import 'package:flutter/foundation.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/repositories/tower_repository.dart';

/// MVVM ViewModel managing Tower Detail screen state, Minetur technical records, and sector telemetry.
class TowerDetailViewModel extends ChangeNotifier {
  final TowerRepository _towerRepository;

  TowerModel _tower;
  TowerModel get tower => _tower;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  TowerDetailViewModel({
    required TowerModel initialTower,
    TowerRepository? towerRepository,
  })  : _tower = initialTower,
        _towerRepository = towerRepository ?? TowerRepositoryImpl();

  Future<void> fetchTechnicalDetails() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _towerRepository.getTowerTechnicalDetails(_tower);
      _tower = updated;
    } catch (e) {
      debugPrint('[TowerDetailViewModel] Detail error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
