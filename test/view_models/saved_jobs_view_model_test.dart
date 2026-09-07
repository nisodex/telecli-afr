import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/data/models/installation_job.dart';
import 'package:telecli_afr/data/repositories/installation_job_repository.dart';
import 'package:telecli_afr/ui/features/jobs/view_models/saved_jobs_view_model.dart';

class MockJobRepository implements InstallationJobRepository {
  final List<InstallationJob> _db = [];

  @override
  Future<List<InstallationJob>> getAllJobs() async => List.from(_db);

  @override
  Future<void> saveJob(InstallationJob job) async {
    _db.removeWhere((j) => j.id == job.id);
    _db.add(job);
  }

  @override
  Future<void> deleteJob(String id) async {
    _db.removeWhere((j) => j.id == id);
  }
}

void main() {
  group('SavedJobsViewModel Tests', () {
    test('Loads, saves, and deletes installation jobs correctly', () async {
      final repo = MockJobRepository();
      final viewModel = SavedJobsViewModel(jobRepository: repo);

      await viewModel.loadJobs();
      expect(viewModel.jobs.isEmpty, isTrue);

      final job = InstallationJob(
        id: 'job-1',
        clientName: 'Cliente Prueba AFR',
        clientAddress: 'Calle Alcalá 50',
        clientLat: 40.42,
        clientLon: -3.70,
        towerId: 't-1',
        towerCode: 'EST-01',
        towerAddress: 'Torre Centro',
        targetBearing: 180,
        distanceMeters: 400,
        technologyBand: '5G n78 (3.5 GHz)',
        createdAt: DateTime.now(),
        fsplDb: 95.4,
        fresnelRadiusMeters: 2.9,
      );

      await viewModel.saveJob(job);
      expect(viewModel.jobs.length, equals(1));
      expect(viewModel.jobs.first.clientName, equals('Cliente Prueba AFR'));

      await viewModel.deleteJob('job-1');
      expect(viewModel.jobs.isEmpty, isTrue);
    });
  });
}
