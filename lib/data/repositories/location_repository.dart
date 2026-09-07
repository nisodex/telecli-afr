import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

/// Abstract contract for Device Location and Geocoding.
abstract class LocationRepository {
  Future<Position> getCurrentPosition();
  Future<String> reverseGeocode(double lat, double lon);
}

/// Geolocator & Nominatim backed implementation of LocationRepository.
class LocationRepositoryImpl implements LocationRepository {
  final LocationService _locationService;

  LocationRepositoryImpl({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  @override
  Future<Position> getCurrentPosition() {
    return _locationService.getCurrentPosition();
  }

  @override
  Future<String> reverseGeocode(double lat, double lon) {
    return _locationService.reverseGeocode(lat, lon);
  }
}
