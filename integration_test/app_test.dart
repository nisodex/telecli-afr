import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telecli_afr/main.dart';
import 'package:telecli_afr/ui/screens/home_screen.dart';
import 'package:telecli_afr/ui/screens/map_screen.dart';
import 'package:telecli_afr/ui/screens/saved_jobs_screen.dart';
import 'package:telecli_afr/ui/screens/tower_list_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getCurrentPosition') {
          return {
            'latitude': 40.4168,
            'longitude': -3.7038,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'altitude': 650.0,
            'accuracy': 5.0,
            'heading': 90.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
          };
        }
        return null;
      },
    );
  });

  group('Movistar AFR 5G End-To-End App Integration Tests', () {
    testWidgets('App launches, displays navigation shell, and switches tabs seamlessly', (tester) async {
      await tester.pumpWidget(const MovistarAfr5gApp());
      await tester.pumpAndSettle();

      // 1. Verify HomeScreen is visible initially
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('AFR 5G'), findsWidgets);
      expect(find.text('HERRAMIENTAS DE ORIENTACIÓN'), findsOneWidget);

      // 2. Navigate to Map tab
      final mapTabFinder = find.byIcon(Icons.map_outlined);
      expect(mapTabFinder, findsOneWidget);
      await tester.tap(mapTabFinder);
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsOneWidget);

      // 3. Navigate to Tower List tab (Censo Minetur)
      final towersTabFinder = find.byIcon(Icons.cell_tower_outlined);
      expect(towersTabFinder, findsOneWidget);
      await tester.tap(towersTabFinder);
      await tester.pumpAndSettle();
      expect(find.byType(TowerListScreen), findsOneWidget);

      // 4. Navigate to Saved Jobs tab (Obras)
      final jobsTabFinder = find.byIcon(Icons.assignment_outlined);
      expect(jobsTabFinder, findsOneWidget);
      await tester.tap(jobsTabFinder);
      await tester.pumpAndSettle();
      expect(find.byType(SavedJobsScreen), findsOneWidget);
      expect(find.text('Historial de Instalaciones'), findsOneWidget);

      // 5. Navigate back to Home tab
      final homeTabFinder = find.byIcon(Icons.home_outlined);
      expect(homeTabFinder, findsOneWidget);
      await tester.tap(homeTabFinder);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
