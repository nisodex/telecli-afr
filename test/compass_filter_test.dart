import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/core/utils/compass_filter.dart';

void main() {
  group('CompassFilter Tests', () {
    test('Smooths angle transitions without boundary glitches', () {
      final filter = CompassFilter(alpha: 0.5);

      // Start at 350°
      final first = filter.filter(350.0);
      expect(first, closeTo(350.0, 0.1));

      // Move across 0° boundary to 10°
      final second = filter.filter(10.0);

      // Average between 350° (-10°) and +10° with alpha 0.5 should be 0° (or 360°)
      expect(second, closeTo(0.0, 1.0));
    });

    test('Filter resets cleanly', () {
      final filter = CompassFilter();
      filter.filter(90.0);
      filter.reset();

      final firstAfterReset = filter.filter(180.0);
      expect(firstAfterReset, closeTo(180.0, 0.1));
    });
  });
}
