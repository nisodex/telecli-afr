import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/utils/compass_filter.dart';

/// Data class holding current device orientation and sensor telemetry in 3D space.
class DeviceOrientationData {
  final double heading; // 0° to 360° azimuth from North
  final double pitch;   // Forward/backward tilt (-90° to +90°)
  final double roll;    // Left/right tilt (-180° to +180°)
  final double accuracy;// Sensor accuracy in degrees
  final double magneticFieldMicroTesla;
  final bool hasMagneticDisturbance;

  const DeviceOrientationData({
    required this.heading,
    required this.pitch,
    required this.roll,
    this.accuracy = 5.0,
    this.magneticFieldMicroTesla = 45.0,
    this.hasMagneticDisturbance = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceOrientationData &&
        other.heading == heading &&
        other.pitch == pitch &&
        other.roll == roll &&
        other.accuracy == accuracy &&
        other.magneticFieldMicroTesla == magneticFieldMicroTesla &&
        other.hasMagneticDisturbance == hasMagneticDisturbance;
  }

  @override
  int get hashCode => Object.hash(
        heading,
        pitch,
        roll,
        accuracy,
        magneticFieldMicroTesla,
        hasMagneticDisturbance,
      );
}

/// High-performance sensor service managing hardware magnetometer, accelerometer,
/// and haptic feedback with 60 FPS hardware throttling (~16.6ms budget) and ValueNotifiers.
class SensorsService {
  final CompassFilter _compassFilter = CompassFilter(alpha: 0.22);
  StreamSubscription? _compassSub;
  StreamSubscription? _accelSub;
  StreamSubscription? _magSub;

  final StreamController<DeviceOrientationData> _orientationController =
      StreamController<DeviceOrientationData>.broadcast();

  Stream<DeviceOrientationData> get orientationStream => _orientationController.stream;

  // 60 FPS ValueNotifiers for zero-rebuild surgical UI updates
  final ValueNotifier<double> headingNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> pitchNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> rollNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<DeviceOrientationData> orientationNotifier =
      ValueNotifier<DeviceOrientationData>(const DeviceOrientationData(
    heading: 0.0,
    pitch: 0.0,
    roll: 0.0,
  ));

  double _currentHeading = 0.0;
  double _currentPitch = 0.0;
  double _currentRoll = 0.0;
  double _accuracy = 5.0;
  double _magX = 0.0, _magY = 0.0, _magZ = 0.0;
  double _magMagnitude = 45.0; // Typical Earth magnetic field in Spain (45 uT)
  bool _hasMagneticDisturbance = false;
  double _accelX = 0.0, _accelY = 0.0, _accelZ = 9.8;

  bool _isListening = false;
  DateTime _lastHapticTime = DateTime.now();

  // 60 FPS Frame Budget Throttle (16,000 microseconds = 60 Hz)
  static const int _frameIntervalUs = 16000;
  final Stopwatch _stopwatch = Stopwatch();
  int _lastEmitUs = 0;
  Timer? _throttleTimer;

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _stopwatch.start();

    // 1. Listen to Accelerometer for Pitch & Roll (bubble level)
    try {
      _accelSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((event) {
        _accelX = event.x;
        _accelY = event.y;
        _accelZ = event.z;

        // Calculate pitch (elevation angle above horizon) and roll (lateral tilt)
        // In mobile AR, telecommunications, and field alignment:
        // PITCH represents the elevation tilt angle of the device/camera boresight relative to Earth's horizontal plane:
        // - 0.0°: Perfectly level with the horizon (phone held upright in portrait, pointing at horizon)
        // - Positive (> 0°): Tilted UPWARDS towards the sky, rooftops, or tower mast (+5°, +15°, etc.)
        // - Negative (< 0°): Tilted DOWNWARDS towards the ground (-5°, -15°, etc.)
        final double xyNorm = math.sqrt(_accelX * _accelX + _accelY * _accelY);
        if (xyNorm > 0.1) {
          // Camera optical axis is along -Z. Normal reaction to gravity is (_accelX, _accelY, _accelZ).
          // Elevation angle above the horizontal plane:
          _currentPitch = math.atan2(-_accelZ, xyNorm) * 180.0 / math.pi;
          _currentRoll = math.atan2(-_accelX, _accelY) * 180.0 / math.pi;
        } else {
          // Zenith / Nadir boundary condition
          _currentPitch = _accelZ > 0 ? -90.0 : 90.0;
          _currentRoll = 0.0;
        }

        _throttledEmit();
      }, onError: (e) {
        debugPrint('[SensorsService] Accelerometer error: $e');
      });
    } catch (e) {
      debugPrint('[SensorsService] Accelerometer init error: $e');
    }

    // 2. Continuous Magnetometer monitoring for Field Magnitude and Metal/Mast Interference
    try {
      _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((event) {
        _magX = event.x;
        _magY = event.y;
        _magZ = event.z;
        _magMagnitude = math.sqrt(_magX * _magX + _magY * _magY + _magZ * _magZ);
        // Disturbance triggered if < 22 uT or > 75 uT (e.g. nearby metal mast).
        _hasMagneticDisturbance = _magMagnitude < 22.0 || _magMagnitude > 75.0;

        // Fallback heading if compass is unavailable
        if (_compassSub == null) {
          final double rad = math.atan2(_magY, _magX);
          double deg = (rad * 180.0 / math.pi + 360.0) % 360.0;
          _currentHeading = _compassFilter.filter(deg);
          _throttledEmit();
        }
      }, onError: (e) {
        debugPrint('[SensorsService] Magnetometer error: $e');
      });
    } catch (e) {
      debugPrint('[SensorsService] Magnetometer init error: $e');
    }

    // 3. Try flutter_compass for hardware calibrated heading
    try {
      if (FlutterCompass.events != null) {
        _compassSub = FlutterCompass.events!.listen((CompassEvent event) {
          if (event.heading != null) {
            final double rawHeading = (event.heading! + 360.0) % 360.0;
            _currentHeading = _compassFilter.filter(rawHeading);
            _accuracy = event.accuracy ?? 5.0;
            _throttledEmit();
          }
        }, onError: (e) {
          debugPrint('[SensorsService] FlutterCompass stream error: $e');
        });
      }
    } catch (e) {
      debugPrint('[SensorsService] Compass init exception: $e');
    }
  }

  /// 60 FPS Throttler to enforce 16.67ms frame budget and eliminate UI thread congestion
  void _throttledEmit() {
    final int nowUs = _stopwatch.elapsedMicroseconds;
    final int elapsed = nowUs - _lastEmitUs;

    if (elapsed >= _frameIntervalUs) {
      _throttleTimer?.cancel();
      _throttleTimer = null;
      _lastEmitUs = nowUs;
      _emitOrientation();
    } else if (_throttleTimer == null) {
      final int remainingUs = _frameIntervalUs - elapsed;
      _throttleTimer = Timer(Duration(microseconds: remainingUs), () {
        _throttleTimer = null;
        _lastEmitUs = _stopwatch.elapsedMicroseconds;
        _emitOrientation();
      });
    }
  }

  void _emitOrientation() {
    final data = DeviceOrientationData(
      heading: _currentHeading,
      pitch: _currentPitch,
      roll: _currentRoll,
      accuracy: _accuracy,
      magneticFieldMicroTesla: _magMagnitude,
      hasMagneticDisturbance: _hasMagneticDisturbance,
    );

    // Fast synchronous ValueNotifier updates (only subscribed widgets rebuild)
    if (headingNotifier.value != _currentHeading) headingNotifier.value = _currentHeading;
    if (pitchNotifier.value != _currentPitch) pitchNotifier.value = _currentPitch;
    if (rollNotifier.value != _currentRoll) rollNotifier.value = _currentRoll;
    orientationNotifier.value = data;

    if (!_orientationController.isClosed) {
      _orientationController.add(data);
    }
  }

  /// Triggers haptic pulse when technician is aligning antenna
  void triggerAlignmentHaptic(double deviation, {double alignedTolerance = 3.0}) {
    final double absDev = deviation.abs();
    final now = DateTime.now();

    if (absDev <= alignedTolerance) {
      // Aligned: pulse every 220ms
      if (now.difference(_lastHapticTime).inMilliseconds > 220) {
        _lastHapticTime = now;
        HapticFeedback.heavyImpact();
      }
    } else if (absDev <= alignedTolerance * 2.5) {
      // Close to target: pulse every 500ms
      if (now.difference(_lastHapticTime).inMilliseconds > 500) {
        _lastHapticTime = now;
        HapticFeedback.mediumImpact();
      }
    }
  }

  void stopListening() {
    _compassSub?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _stopwatch.stop();
    _compassFilter.reset();
    _isListening = false;
  }

  void dispose() {
    stopListening();
    _orientationController.close();
    headingNotifier.dispose();
    pitchNotifier.dispose();
    rollNotifier.dispose();
    orientationNotifier.dispose();
  }
}
