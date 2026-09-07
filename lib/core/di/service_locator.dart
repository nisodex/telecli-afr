import '../../data/repositories/installation_job_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/tower_repository.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/minetur_service.dart';
import '../../data/services/sensors_service.dart';
import '../../domain/use_cases/calculate_rf_link_use_case.dart';
import '../../domain/use_cases/find_optimal_5g_tower_use_case.dart';

/// Lightweight dependency injection container providing single sources of truth across layers.
class ServiceLocator {
  ServiceLocator._();

  // Services
  static final MineturService mineturService = MineturService();
  static final LocationService locationService = LocationService();
  static final LocalStorageService localStorageService = LocalStorageService();
  static SensorsService createSensorsService() => SensorsService();

  // Repositories
  static final TowerRepository towerRepository = TowerRepositoryImpl(
    mineturService: mineturService,
  );
  static final LocationRepository locationRepository = LocationRepositoryImpl(
    locationService: locationService,
  );
  static final InstallationJobRepository installationJobRepository =
      InstallationJobRepositoryImpl(
    storageService: localStorageService,
  );

  // Use Cases
  static const FindOptimal5gTowerUseCase findOptimal5gTowerUseCase =
      FindOptimal5gTowerUseCase();
  static const CalculateRfLinkUseCase calculateRfLinkUseCase =
      CalculateRfLinkUseCase();
}
