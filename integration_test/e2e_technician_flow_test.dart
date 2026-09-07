import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/ui/screens/compass_alignment_screen.dart';
import 'package:telecli_afr/ui/widgets/compass_rose.dart';
import 'package:telecli_afr/ui/widgets/pitch_roll_indicator.dart';
import 'package:telecli_afr/ui/widgets/rf_calculator_sheet.dart';
import 'package:telecli_afr/ui/widgets/rf_telemetry_card.dart';
import 'package:telecli_afr/ui/widgets/signal_gauge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (MethodCall methodCall) async => null,
    );
  });

  group('Technician E2E Field Alignment & Telemetry Flow', () {
    final testTower = TowerModel(
      id: 'e2e-tower-01',
      code: 'MAD-ALC-3500',
      operator: 'Movistar',
      address: 'Calle Mayor 10, Alcalá de Henares',
      latitude: 40.4819,
      longitude: -3.3635,
      distanceMeters: 450,
      azimuthBearing: 120,
      elevationTilt: -1.8,
      has5Gn78: true,
      has5Gn28: true,
      has4G: true,
      isMovistar: true,
    );

    testWidgets('CompassAlignmentScreen loads full telemetry, bubble level, and triggers save job modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: CompassAlignmentScreen(
            tower: testTower,
            clientLat: 40.4800,
            clientLon: -3.3600,
            clientAddress: 'Plaza de Cervantes, Alcalá de Henares',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 60 FPS Visual Instruments
      expect(find.byType(CompassRose), findsOneWidget);
      expect(find.byType(SignalGauge), findsOneWidget);
      expect(find.byType(PitchRollIndicator), findsOneWidget);
      expect(find.byType(RfTelemetryCard), findsOneWidget);

      // 2. Verify Tower Header Metadata
      expect(find.text('TORRE MOVISTAR 5G (n78)'), findsOneWidget);
      expect(find.text('Calle Mayor 10, Alcalá de Henares'), findsOneWidget);

      // 3. Open Save Job Dialog
      final saveBtnFinder = find.widgetWithText(ElevatedButton, 'GUARDAR OBRA');
      expect(saveBtnFinder, findsOneWidget);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // 4. Verify modal dialog with work order inputs
      expect(find.text('Registrar Instalación AFR 5G'), findsOneWidget);
      expect(find.text('Nombre / Contrato Cliente'), findsOneWidget);
      expect(find.text('Nivel Señal RSRP Medido (dBm)'), findsOneWidget);

      // 5. Fill client details
      final nameFieldFinder = find.widgetWithText(TextField, 'Nombre / Contrato Cliente');
      await tester.enterText(nameFieldFinder, 'Contrato FWA-2026-99');
      await tester.pumpAndSettle();

      // 6. Dismiss dialog safely
      final cancelBtnFinder = find.text('CANCELAR');
      expect(cancelBtnFinder, findsOneWidget);
      await tester.tap(cancelBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Registrar Instalación AFR 5G'), findsNothing);
    });

    testWidgets('RfCalculatorSheet opens and calculates Link Budget dynamically', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RfCalculatorSheet(tower: testTower),
                  );
                },
                child: const Text('OPEN_CALC'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to open calculator sheet
      await tester.tap(find.text('OPEN_CALC'));
      await tester.pumpAndSettle();

      // Verify RF calculation metrics are visible
      expect(find.text('Calculadora de Enlace RF'), findsOneWidget);
      expect(find.text('Pérdidas FSPL:'), findsOneWidget);
      expect(find.text('Radio 1ª Zona Fresnel:'), findsOneWidget);
      expect(find.text('APLICAR EN ORIENTACIÓN'), findsOneWidget);

      // Tap apply button to dismiss
      await tester.tap(find.text('APLICAR EN ORIENTACIÓN'));
      await tester.pumpAndSettle();

      expect(find.byType(RfCalculatorSheet), findsNothing);
    });
  });
}
