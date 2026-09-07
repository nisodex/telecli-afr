import '../../data/models/tower_model.dart';
import '../../data/repositories/installation_job_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/tower_repository.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/minetur_service.dart';
import '../../data/services/province_manager_service.dart';
import '../../data/services/sensors_service.dart';
import '../../data/services/update_service.dart';
import '../../domain/use_cases/calculate_rf_link_use_case.dart';
import '../../domain/use_cases/find_optimal_5g_tower_use_case.dart';
import '../../ui/features/alignment/view_models/alignment_view_model.dart';
import '../../ui/features/map/view_models/map_view_model.dart';
import '../../ui/features/towers/view_models/tower_detail_view_model.dart';

/// Lightweight dependency injection container providing single sources of truth across layers.
class ServiceLocator {
  ServiceLocator._();

  // Services
  static final MineturService mineturService = MineturService();
  static final LocationService locationService = LocationService();
  static final LocalStorageService localStorageService = LocalStorageService();
  static final ProvinceManagerService provinceManagerService = ProvinceManagerService();
  static final UpdateService updateService = UpdateService();
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

  // ViewModel Factories
  static MapViewModel createMapViewModel() => MapViewModel(
        towerRepository: towerRepository,
        locationRepository: locationRepository,
      );

  static TowerDetailViewModel createTowerDetailViewModel(TowerModel tower) =>
      TowerDetailViewModel(
        initialTower: tower,
        towerRepository: towerRepository,
      );

  static AlignmentViewModel createAlignmentViewModel({
    required TowerModel tower,
    required double clientLat,
    required double clientLon,
    String clientAddress = '',
    SensorsService? sensorsService,
  }) =>
      AlignmentViewModel(
        tower: tower,
        clientLat: clientLat,
        clientLon: clientLon,
        clientAddress: clientAddress,
        sensorsService: sensorsService,
        jobRepository: installationJobRepository,
        calculateRfLinkUseCase: calculateRfLinkUseCase,
      );
}
