import 'dart:math' as math;

/// Utility calculations for geospatial alignment of AFR 5G customer premises equipment (CPE).
class GeoCalculator {
  static const double earthRadiusMeters = 6371000.0;

  /// Calculates the spherical distance in meters between two coordinates using the Haversine formula.
  static double calculateDistanceMeters(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    final double phi1 = startLat * math.pi / 180.0;
    final double phi2 = endLat * math.pi / 180.0;
    final double deltaPhi = (endLat - startLat) * math.pi / 180.0;
    final double deltaLambda = (endLon - startLon) * math.pi / 180.0;

    final double a = math.sin(deltaPhi / 2.0) * math.sin(deltaPhi / 2.0) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2.0) *
            math.sin(deltaLambda / 2.0);

    final double c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    return earthRadiusMeters * c;
  }

  /// Calculates the initial forward bearing (azimuth) from start to end in degrees [0, 360).
  static double calculateBearing(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    final double phi1 = startLat * math.pi / 180.0;
    final double phi2 = endLat * math.pi / 180.0;
    final double deltaLambda = (endLon - startLon) * math.pi / 180.0;

    final double y = math.sin(deltaLambda) * math.cos(phi2);
    final double x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final double theta = math.atan2(y, x);
    final double bearing = (theta * 180.0 / math.pi + 360.0) % 360.0;
    return bearing;
  }

  /// Calculates the signed angular deviation between the current device heading and the target bearing.
  /// Result is between -180 and +180 degrees.
  /// - Negative (< 0): Turn LEFT to reach target.
  /// - Positive (> 0): Turn RIGHT to reach target.
  static double calculateAngularDeviation(double currentHeading, double targetBearing) {
    double diff = targetBearing - currentHeading;
    while (diff < -180.0) {
      diff += 360.0;
    }
    while (diff > 180.0) {
      diff -= 360.0;
    }
    return diff;
  }

  /// Calculates the elevation angle (tilt) in degrees from client to tower.
  /// Positive value = antenna should tilt upwards.
  /// Negative value = antenna should tilt downwards.
  static double calculateElevationTilt(
    double distanceMeters,
    double clientHeightMeters,
    double towerHeightMeters,
  ) {
    if (distanceMeters <= 0) return 0.0;
    final double deltaHeight = towerHeightMeters - clientHeightMeters;
    final double tiltRad = math.atan2(deltaHeight, distanceMeters);
    return tiltRad * 180.0 / math.pi;
  }

  /// Converts bearing in degrees to 16-point cardinal compass text (e.g. N, NNE, NE...).
  static String bearingToCardinal(double bearing) {
    const List<String> directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    final int index = ((bearing + 11.25) % 360 / 22.5).floor();
    return directions[index % 16];
  }

  /// Formats distance humanly: e.g. "850 m" or "4.2 km".
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000.0).toStringAsFixed(2)} km';
    }
  }

  /// Generates a bounding box [minLon, minLat, maxLon, maxLat] around a center point for a given radius in km.
  static List<double> calculateBbox(double lat, double lon, double radiusKm) {
    // 1 deg lat approx 111 km
    final double latDelta = radiusKm / 111.0;
    final double cosLat = math.cos(lat * math.pi / 180.0).abs();
    final double lonDelta = radiusKm / (111.0 * (cosLat > 0.01 ? cosLat : 1.0));

    final double minLat = lat - latDelta;
    final double maxLat = lat + latDelta;
    final double minLon = lon - lonDelta;
    final double maxLon = lon + lonDelta;

    return [minLon, minLat, maxLon, maxLat];
  }
}
