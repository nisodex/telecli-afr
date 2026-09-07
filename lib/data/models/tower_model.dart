import '../../core/constants/movistar_constants.dart';

/// Represents a mobile cell tower / base station from Minetur VCTEL.
class TowerModel {
  final String id;
  final String code;
  final String operator;
  final String address;
  final double latitude;
  final double longitude;
  final String detailUrl;
  final List<String> bands;
  final bool has5Gn78; // 3.5 GHz primary band for AFR 5G
  final bool has5Gn28; // 700 MHz rural 5G band
  final bool has4G;    // 4G LTE
  final bool has3G;    // 3G UMTS (900/2100 MHz)
  final bool has2G;    // 2G GSM (900/1800 MHz)
  final bool isMovistar;
  final double? radiationLevel; // In uW/cm2
  final List<double> sectorAzimuths;

  // Transient calculated fields relative to client/technician location
  double distanceMeters;
  double azimuthBearing;
  double elevationTilt;

  TowerModel({
    required this.id,
    required this.code,
    required this.operator,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.detailUrl = '',
    this.bands = const [],
    this.has5Gn78 = false,
    this.has5Gn28 = false,
    this.has4G = true,
    this.has3G = false,
    this.has2G = false,
    required this.isMovistar,
    this.radiationLevel,
    this.sectorAzimuths = const [],
    this.distanceMeters = 0.0,
    this.azimuthBearing = 0.0,
    this.elevationTilt = 0.0,
  });

  /// Factory constructor to parse a GeoJSON feature from Minetur infoantenasGeoJSON.do.
  factory TowerModel.fromMineturGeoJson(Map<String, dynamic> feature) {
    final properties = (feature['properties'] as Map<String, dynamic>?) ?? {};
    final geometry = (feature['geometry'] as Map<String, dynamic>?) ?? {};
    final coordinates = (geometry['coordinates'] as List<dynamic>?) ?? [0.0, 0.0];

    final double lon = coordinates.isNotEmpty ? (coordinates[0] as num).toDouble() : 0.0;
    final double lat = coordinates.length > 1 ? (coordinates[1] as num).toDouble() : 0.0;

    final String id = properties['Gis_ID']?.toString() ?? properties['id']?.toString() ?? '';
    final String code = properties['Gis_Codigo']?.toString() ?? properties['Código']?.toString() ?? '';
    final String address = properties['Dirección']?.toString() ?? properties['Direccin']?.toString() ?? 'Sin dirección';
    final String detail = properties['Detalle']?.toString() ?? '';

    // Extract operator from code or properties
    String op = 'Desconocido';
    if (code.contains('-')) {
      op = code.split('-').first.trim();
    } else if (properties.containsKey('Operador')) {
      op = properties['Operador']?.toString() ?? '';
    }

    final String codeUpper = code.toUpperCase();
    final bool isMov = MovistarConstants.movistarKeywords.any((k) => codeUpper.contains(k));

    return TowerModel(
      id: id,
      code: code,
      operator: op,
      address: address,
      latitude: lat,
      longitude: lon,
      detailUrl: detail,
      isMovistar: isMov,
    );
  }

  /// Creates a copy with technical details enriched from detalleEstacion.do
  TowerModel copyWithTechnicalDetails({
    List<String>? bands,
    bool? has5Gn78,
    bool? has5Gn28,
    bool? has4G,
    bool? has3G,
    bool? has2G,
    double? radiationLevel,
    List<double>? sectorAzimuths,
  }) {
    return TowerModel(
      id: id,
      code: code,
      operator: operator,
      address: address,
      latitude: latitude,
      longitude: longitude,
      detailUrl: detailUrl,
      bands: bands ?? this.bands,
      has5Gn78: has5Gn78 ?? this.has5Gn78,
      has5Gn28: has5Gn28 ?? this.has5Gn28,
      has4G: has4G ?? this.has4G,
      has3G: has3G ?? this.has3G,
      has2G: has2G ?? this.has2G,
      isMovistar: isMovistar,
      radiationLevel: radiationLevel ?? this.radiationLevel,
      sectorAzimuths: sectorAzimuths ?? this.sectorAzimuths,
      distanceMeters: distanceMeters,
      azimuthBearing: azimuthBearing,
      elevationTilt: elevationTilt,
    );
  }

  /// SQLite serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'operator': operator,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'detailUrl': detailUrl,
      'bands': bands.join(','),
      'has5Gn78': has5Gn78 ? 1 : 0,
      'has5Gn28': has5Gn28 ? 1 : 0,
      'has4G': has4G ? 1 : 0,
      'has3G': has3G ? 1 : 0,
      'has2G': has2G ? 1 : 0,
      'isMovistar': isMovistar ? 1 : 0,
      'radiationLevel': radiationLevel,
      'sectorAzimuths': sectorAzimuths.join(','),
    };
  }

  factory TowerModel.fromMap(Map<String, dynamic> map) {
    final bandsRaw = map['bands']?.toString() ?? '';
    final sectorsRaw = map['sectorAzimuths']?.toString() ?? '';

    return TowerModel(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      operator: map['operator']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      detailUrl: map['detailUrl']?.toString() ?? '',
      bands: bandsRaw.isNotEmpty ? bandsRaw.split(',') : [],
      has5Gn78: (map['has5Gn78'] as int? ?? 0) == 1,
      has5Gn28: (map['has5Gn28'] as int? ?? 0) == 1,
      has4G: (map['has4G'] as int? ?? 1) == 1,
      has3G: (map['has3G'] as int? ?? 0) == 1,
      has2G: (map['has2G'] as int? ?? 0) == 1,
      isMovistar: (map['isMovistar'] as int? ?? 0) == 1,
      radiationLevel: map['radiationLevel'] != null ? (map['radiationLevel'] as num).toDouble() : null,
      sectorAzimuths: sectorsRaw.isNotEmpty
          ? sectorsRaw.split(',').map((s) => double.tryParse(s) ?? 0.0).toList()
          : [],
    );
  }

  TowerModel copyWith({
    String? id,
    String? code,
    String? operator,
    String? address,
    double? latitude,
    double? longitude,
    String? detailUrl,
    List<String>? bands,
    bool? has5Gn78,
    bool? has5Gn28,
    bool? has4G,
    bool? has3G,
    bool? has2G,
    bool? isMovistar,
    double? radiationLevel,
    List<double>? sectorAzimuths,
    double? distanceMeters,
    double? azimuthBearing,
    double? elevationTilt,
  }) {
    return TowerModel(
      id: id ?? this.id,
      code: code ?? this.code,
      operator: operator ?? this.operator,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      detailUrl: detailUrl ?? this.detailUrl,
      bands: bands ?? this.bands,
      has5Gn78: has5Gn78 ?? this.has5Gn78,
      has5Gn28: has5Gn28 ?? this.has5Gn28,
      has4G: has4G ?? this.has4G,
      has3G: has3G ?? this.has3G,
      has2G: has2G ?? this.has2G,
      isMovistar: isMovistar ?? this.isMovistar,
      radiationLevel: radiationLevel ?? this.radiationLevel,
      sectorAzimuths: sectorAzimuths ?? this.sectorAzimuths,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      azimuthBearing: azimuthBearing ?? this.azimuthBearing,
      elevationTilt: elevationTilt ?? this.elevationTilt,
    );
  }
}
