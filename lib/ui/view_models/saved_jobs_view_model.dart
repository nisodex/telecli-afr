import 'package:flutter/foundation.dart';
import '../../data/models/installation_job.dart';
import '../../data/repositories/installation_job_repository.dart';

/// MVVM ViewModel managing saved installation jobs and official work orders.
class SavedJobsViewModel extends ChangeNotifier {
  final InstallationJobRepository _jobRepository;

  SavedJobsViewModel({InstallationJobRepository? jobRepository})
      : _jobRepository = jobRepository ?? InstallationJobRepositoryImpl();

  List<InstallationJob> _jobs = [];
  List<InstallationJob> get jobs => List.unmodifiable(_jobs);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> loadJobs() async {
    _isLoading = true;
    notifyListeners();

    try {
      _jobs = await _jobRepository.getAllJobs();
    } catch (e) {
      debugPrint('[SavedJobsViewModel] loadJobs error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveJob(InstallationJob job) async {
    await _jobRepository.saveJob(job);
    await loadJobs();
  }

  Future<void> deleteJob(String id) async {
    await _jobRepository.deleteJob(id);
    await loadJobs();
  }
}
