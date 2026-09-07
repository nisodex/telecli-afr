import '../models/installation_job.dart';
import '../services/local_storage_service.dart';

/// Abstract contract for Installation Job / Work Order persistence.
abstract class InstallationJobRepository {
  Future<List<InstallationJob>> getAllJobs();
  Future<void> saveJob(InstallationJob job);
  Future<void> deleteJob(String id);
}

/// SQLite-backed implementation of InstallationJobRepository.
class InstallationJobRepositoryImpl implements InstallationJobRepository {
  final LocalStorageService _storageService;

  InstallationJobRepositoryImpl({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService();

  @override
  Future<List<InstallationJob>> getAllJobs() {
    return _storageService.getAllJobs();
  }

  @override
  Future<void> saveJob(InstallationJob job) {
    return _storageService.saveJob(job);
  }

  @override
  Future<void> deleteJob(String id) {
    return _storageService.deleteJob(id);
  }
}
