import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/ui/widgets/compass_rose.dart';
import 'package:telecli_afr/ui/widgets/pitch_roll_indicator.dart';
import 'package:telecli_afr/ui/widgets/signal_gauge.dart';

void main() {
  testWidgets('CompassRose renders with heading and target bearing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompassRose(
            currentHeading: 142.0,
            targetBearing: 145.0,
            toleranceDegrees: 3.0,
          ),
        ),
      ),
    );

    expect(find.text('142°'), findsOneWidget);
    expect(find.text('TORRE: 145°'), findsOneWidget);
  });

  testWidgets('SignalGauge renders alignment cue', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SignalGauge(
            deviation: 0.0,
            alignedTolerance: 3.0,
          ),
        ),
      ),
    );

    expect(find.text('¡ANTENA ALINEADA!'), findsOneWidget);
  });

  testWidgets('PitchRollIndicator renders bubble level readouts', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PitchRollIndicator(
            pitch: 2.5,
            roll: 0.0,
            targetTilt: 2.5,
          ),
        ),
      ),
    );

    expect(find.text('NIVEL Y ELEVACIÓN'), findsOneWidget);
    expect(find.text('NIVELADO'), findsOneWidget);
  });
}
