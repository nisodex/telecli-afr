import 'dart:math' as math;

/// Circular low-pass filter using trigonometric component averaging.
/// Prevents jitter and handles the 359° <-> 0° boundary smoothly.
class CompassFilter {
  final double alpha; // Smoothing factor (0.0 to 1.0). Lower = smoother, higher = faster response.
  double _sinAvg = 0.0;
  double _cosAvg = 1.0;
  bool _initialized = false;

  CompassFilter({this.alpha = 0.25});

  /// Adds a new raw heading reading and returns the filtered smoothed heading [0, 360).
  double filter(double rawHeadingDegrees) {
    final double rad = rawHeadingDegrees * math.pi / 180.0;
    final double s = math.sin(rad);
    final double c = math.cos(rad);

    if (!_initialized) {
      _sinAvg = s;
      _cosAvg = c;
      _initialized = true;
    } else {
      _sinAvg = (1.0 - alpha) * _sinAvg + alpha * s;
      _cosAvg = (1.0 - alpha) * _cosAvg + alpha * c;
    }

    final double smoothedRad = math.atan2(_sinAvg, _cosAvg);
    final double smoothedDeg = (smoothedRad * 180.0 / math.pi + 360.0) % 360.0;
    return smoothedDeg;
  }

  void reset() {
    _initialized = false;
    _sinAvg = 0.0;
    _cosAvg = 1.0;
  }
}
