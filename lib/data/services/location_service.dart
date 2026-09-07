import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Handles high-precision GPS positioning and reverse geocoding for the technician.
class LocationService {
  static const double defaultLat = 40.416775; // Madrid Puerta del Sol fallback
  static const double defaultLon = -3.703790;
  static Position? lastPosition;

  /// Checks and requests location permission if necessary.
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] Location services are disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationService] Location permission denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationService] Location permissions permanently denied.');
      return false;
    }

    return true;
  }

  /// Obtains current GPS position with high accuracy.
  Future<Position> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) {
      return lastPosition ?? _createFallbackPosition();
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      lastPosition = pos;
      return pos;
    } catch (e) {
      debugPrint('[LocationService] Failed to get live position: $e. Using fallback.');
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        lastPosition = last;
        return last;
      }
      return lastPosition ?? _createFallbackPosition();
    }
  }

  /// Streams real-time position updates as the technician moves on site.
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // Emit every 2 meters of movement
      ),
    );
  }

  /// Reverse geocodes coordinates to a human-readable street address using OpenStreetMap Nominatim.
  Future<String> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MovistarAFR5G_FieldApp/1.0 (telecom@movistar.es)'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // Format shorter address
          final parts = displayName.split(',');
          if (parts.length >= 3) {
            return '${parts[0].trim()}, ${parts[1].trim()}, ${parts[2].trim()}';
          }
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Reverse geocode error: $e');
    }
    return '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
  }

  /// Searches coordinates for a given address query in Spain
  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=es&limit=5',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MovistarAFR5G_FieldApp/1.0 (telecom@movistar.es)'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => {
          'displayName': item['display_name'] as String,
          'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
          'lon': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
        }).toList();
      }
    } catch (e) {
      debugPrint('[LocationService] Address search error: $e');
    }
    return [];
  }

  Position _createFallbackPosition() {
    return Position(
      latitude: defaultLat,
      longitude: defaultLon,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 650.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 5.0,
      headingAccuracy: 5.0,
    );
  }
}
