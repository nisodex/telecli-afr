import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/core/constants/movistar_constants.dart';
import 'package:telecli_afr/data/models/installation_job.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/repositories/installation_job_repository.dart';
import 'package:telecli_afr/data/services/sensors_service.dart';
import 'package:telecli_afr/domain/use_cases/calculate_rf_link_use_case.dart';
import 'package:telecli_afr/ui/features/alignment/view_models/alignment_view_model.dart';

class FakeInstallationJobRepository implements InstallationJobRepository {
  final List<InstallationJob> savedJobs = [];

  @override
  Future<List<InstallationJob>> getAllJobs() async => List.unmodifiable(savedJobs);

  @override
  Future<void> saveJob(InstallationJob job) async {
    savedJobs.add(job);
  }

  @override
  Future<void> deleteJob(String id) async {
    savedJobs.removeWhere((j) => j.id == id);
  }
}

class FakeSensorsService extends SensorsService {
  int hapticTriggerCount = 0;
  double? lastDeviationHaptic;

  @override
  void startListening() {
    // Simulated sensor in test environment
  }

  @override
  void stopListening() {
    // Simulated
  }

  @override
  void triggerAlignmentHaptic(double deviation, {double alignedTolerance = 3.0}) {
    hapticTriggerCount++;
    lastDeviationHaptic = deviation;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlignmentViewModel Tests', () {
    late TowerModel testTower;
    late FakeInstallationJobRepository fakeJobRepo;
    late FakeSensorsService fakeSensors;
    const double clientLat = 40.4168;
    const double clientLon = -3.7038;
    const String clientAddress = 'Puerta del Sol 1, Madrid';

    setUp(() {
      testTower = TowerModel(
        id: 'tower-align-1',
        code: 'MAD-5G-01',
        operator: 'Movistar',
        address: 'Calle Mayor 10, Madrid',
        latitude: 40.4175,
        longitude: -3.7060,
        distanceMeters: 450.0,
        azimuthBearing: 135.0,
        elevationTilt: 3.5,
        has5Gn78: true,
        isMovistar: true,
      );
      fakeJobRepo = FakeInstallationJobRepository();
      fakeSensors = FakeSensorsService();
    });

    test('initializes with target tower, calculates theoretical tilt, and enables haptics', () {
      final viewModel = AlignmentViewModel(
        tower: testTower,
        clientLat: clientLat,
        clientLon: clientLon,
        clientAddress: clientAddress,
        sensorsService: fakeSensors,
        jobRepository: fakeJobRepo,
      );

      expect(viewModel.tower.id, equals('tower-align-1'));
      expect(viewModel.clientLat, equals(clientLat));
      expect(viewModel.clientLon, equals(clientLon));
      expect(viewModel.clientAddress, equals(clientAddress));
      expect(viewModel.hapticEnabled, isTrue);
      expect(viewModel.elevationTilt, isNotNull);
      expect(viewModel.elevationTilt, greaterThan(0.0));
      expect(viewModel.sensorsService, equals(fakeSensors));

      viewModel.dispose();
    });

    test('toggleHaptic toggles state and notifies listeners', () {
      final viewModel = AlignmentViewModel(
        tower: testTower,
        clientLat: clientLat,
        clientLon: clientLon,
        sensorsService: fakeSensors,
        jobRepository: fakeJobRepo,
      );

      int notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      expect(viewModel.hapticEnabled, isTrue);

      viewModel.toggleHaptic();
      expect(viewModel.hapticEnabled, isFalse);
      expect(notifyCount, equals(1));

      viewModel.toggleHaptic();
      expect(viewModel.hapticEnabled, isTrue);
      expect(notifyCount, equals(2));

      viewModel.dispose();
    });

    test('calculates angular deviation correctly relative to tower azimuth', () {
      final viewModel = AlignmentViewModel(
        tower: testTower, // bearing = 135.0
        clientLat: clientLat,
        clientLon: clientLon,
        sensorsService: fakeSensors,
        jobRepository: fakeJobRepo,
      );

      // Current heading = 135.0 -> dev = 0.0
      expect(viewModel.calculateDeviation(135.0), closeTo(0.0, 0.01));
      expect(viewModel.isHeadingAligned(135.0), isTrue);

      // Current heading = 137.0 (past target) -> dev = -2.0 (turn left 2.0°)
      expect(viewModel.calculateDeviation(137.0), closeTo(-2.0, 0.01));
      expect(viewModel.isHeadingAligned(137.0), isTrue);

      // Current heading = 150.0 (past target) -> dev = -15.0 (turn left 15.0°)
      expect(viewModel.calculateDeviation(150.0), closeTo(-15.0, 0.01));
      expect(viewModel.isHeadingAligned(150.0), isFalse);

      // Current heading = 130.0 (before target) -> dev = +5.0 (turn right 5.0°)
      expect(viewModel.calculateDeviation(130.0), closeTo(5.0, 0.01));
      expect(viewModel.isHeadingAligned(130.0), isFalse);

      viewModel.dispose();
    });

    test('pitch alignment evaluates against target elevation tilt', () {
      final viewModel = AlignmentViewModel(
        tower: testTower,
        clientLat: clientLat,
        clientLon: clientLon,
        sensorsService: fakeSensors,
        jobRepository: fakeJobRepo,
      );

      final tilt = viewModel.elevationTilt;

      // Perfectly matching pitch
      expect(viewModel.isPitchAligned(tilt), isTrue);

      // Slightly off within tolerance
      expect(viewModel.isPitchAligned(tilt + (MovistarConstants.defaultAlignedToleranceDegrees - 0.5)), isTrue);

      // Off beyond tolerance
      expect(viewModel.isPitchAligned(tilt + 10.0), isFalse);

      // Full alignment check (heading & pitch)
      expect(viewModel.isFullyAligned(135.0, tilt), isTrue);
      expect(viewModel.isFullyAligned(160.0, tilt), isFalse);
      expect(viewModel.isFullyAligned(135.0, tilt + 10.0), isFalse);

      viewModel.dispose();
    });

    test('calculateRfLink executes domain use case and produces telemetry', () {
      final viewModel = AlignmentViewModel(
        tower: testTower,
        clientLat: clientLat,
        clientLon: clientLon,
        sensorsService: fakeSensors,
        jobRepository: fakeJobRepo,
        calculateRfLinkUseCase: const CalculateRfLinkUseCase(),
      );

      final telemetry = viewModel.calculateRfLink(currentHeading: 135.0);

      expect(telemetry.fsplDb, greaterThan(80.0));
      expect(telemetry.fresnelRadiusMeters, greaterThan(0.0));
      expect(telemetry.estimatedRsrpDbm, lessThan(0.0));
      expect(telemetry.estimatedDownlinkMbps, greaterThan(0));
      expect(telemetry.isInsideMainBeam, isTrue);

      viewModel.dispose();
    });

    test('saveInstallationJob computes RF telemetry and saves job to repository', () async {
      final viewModel = AlignmentViewModel(
        tower: testTower,
        clientLat: clientLat,
        clientLon: clientLon,
        clientAddress: clientAddress,
        sensorsService: fakeSensors,
        jobRepository: fakeJobRepo,
      );

      expect(fakeJobRepo.savedJobs, isEmpty);

      await viewModel.saveInstallationJob(
        clientName: 'Cliente Test 5G',
        notes: 'Mástil 48mm galvanizado, LOS directo',
        rsrpDbm: -76,
        currentPitch: 3.5,
        currentHeading: 135.0,
      );

      expect(fakeJobRepo.savedJobs.length, equals(1));
      final savedJob = fakeJobRepo.savedJobs.first;

      expect(savedJob.clientName, equals('Cliente Test 5G'));
      expect(savedJob.clientAddress, equals(clientAddress));
      expect(savedJob.towerId, equals('tower-align-1'));
      expect(savedJob.towerCode, equals('MAD-5G-01'));
      expect(savedJob.targetBearing, equals(135.0));
      expect(savedJob.distanceMeters, equals(450.0));
      expect(savedJob.technologyBand, contains('5G n78'));
      expect(savedJob.rsrpDbm, equals(-76));
      expect(savedJob.notes, equals('Mástil 48mm galvanizado, LOS directo'));
      expect(savedJob.fsplDb, isNotNull);
      expect(savedJob.fsplDb!, greaterThan(80.0));
      expect(savedJob.mechanicalTiltDeg, equals(3.5));

      viewModel.dispose();
    });
  });
}
