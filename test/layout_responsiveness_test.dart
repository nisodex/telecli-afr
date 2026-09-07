import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/services/sensors_service.dart';
import 'package:telecli_afr/ui/core/widgets/tower_card.dart';
import 'package:telecli_afr/data/repositories/tower_repository.dart';
import 'package:telecli_afr/ui/core/widgets/rf_telemetry_card.dart';
import 'package:telecli_afr/ui/core/widgets/rf_calculator_sheet.dart';
import 'package:telecli_afr/ui/features/towers/view_models/tower_detail_view_model.dart';
import 'package:telecli_afr/ui/features/towers/views/tower_detail_screen.dart';

void main() {
  final sampleTower = TowerModel(
    id: 'TEST_001',
    code: 'MAD_4091_A',
    operator: 'Telefónica de España S.A.U.',
    address: 'Camino de las Huertas 45, Pozuelo de Alarcón (Madrid)',
    latitude: 40.4358,
    longitude: -3.8123,
    distanceMeters: 1450.0,
    azimuthBearing: 348.5,
    elevationTilt: 1.8,
    isMovistar: true,
    has5Gn78: true,
    has5Gn28: true,
    has4G: true,
    has3G: true,
    has2G: true,
  );

  testWidgets('TowerCard renders without overflow on 320dp narrow device', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TowerCard(
            tower: sampleTower,
            onSelect: () {},
            onAlign: () {},
            onDetails: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('DISTANCIA'), findsOneWidget);
    expect(find.text('RUMBO / AZIMUT'), findsOneWidget);
  });

  testWidgets('RfTelemetryCard renders without overflow on 320dp narrow device', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RfTelemetryCard(
              tower: sampleTower,
              sensorData: const DeviceOrientationData(
                heading: 348.0,
                pitch: 1.5,
                roll: 0.2,
                accuracy: 3.0,
                magneticFieldMicroTesla: 48.2,
                hasMagneticDisturbance: false,
              ),
              currentHeading: 348.0,
              clientLat: 40.4300,
              clientLon: -3.8100,
              onOpenCalculator: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('TELEMETRÍA RF Y ENLACE AVANZADO'), findsOneWidget);
  });

  testWidgets('RfCalculatorSheet renders without overflow on 360dp device', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2.0, 740 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RfCalculatorSheet(
            tower: sampleTower,
          ),
        ),
      ),
    );

    final err = tester.takeException();
    if (err is FlutterError) {
      // ignore: avoid_print
      print(err.toStringDeep());
    }
    expect(err, isNull);
  });

  testWidgets('TowerDetailScreen renders without overflow on 320dp narrow device', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final vm = TowerDetailViewModel(
      initialTower: sampleTower,
      towerRepository: FakeDetailTowerRepo(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TowerDetailScreen(
          tower: sampleTower,
          viewModel: vm,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('LOCALIZACIÓN OFICIAL'), findsOneWidget);
    expect(find.text('PÉRDIDA ESPACIO LIBRE'), findsOneWidget);
  });
}

class FakeDetailTowerRepo implements TowerRepository {
  @override
  Future<List<TowerModel>> getTowersAroundLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    bool onlyMovistar = true,
  }) async => [];

  @override
  Future<TowerModel?> getTowerById(String id) async => null;

  @override
  Future<TowerModel> getTowerTechnicalDetails(TowerModel tower) async => tower;
}

