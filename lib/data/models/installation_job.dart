/// Represents an antenna installation report saved by the field technician with advanced RF engineering telemetry.
class InstallationJob {
  final String id;
  final String clientName;
  final String clientAddress;
  final double clientLat;
  final double clientLon;
  final String towerId;
  final String towerCode;
  final String towerAddress;
  final double targetBearing;
  final double distanceMeters;
  final String technologyBand;
  final int? signalRssiDbm;
  final int? rsrpDbm;
  final double? sinrDb;
  final String notes;
  final DateTime createdAt;
  final String status;

  // Advanced RF & Telemetry engineering fields
  final double? fsplDb;
  final double? fresnelRadiusMeters;
  final double? estimatedRsrpDbm;
  final int? downlinkEstimatedMbps;
  final double? mechanicalTiltDeg;
  final double? magneticDeclinationDeg;
  final double? gpsAccuracyMeters;
  final double? clientAltitudeMeters;

  InstallationJob({
    required this.id,
    required this.clientName,
    required this.clientAddress,
    required this.clientLat,
    required this.clientLon,
    required this.towerId,
    required this.towerCode,
    required this.towerAddress,
    required this.targetBearing,
    required this.distanceMeters,
    required this.technologyBand,
    this.signalRssiDbm,
    this.rsrpDbm,
    this.sinrDb,
    this.notes = '',
    required this.createdAt,
    this.status = 'Alineada y completada',
    this.fsplDb,
    this.fresnelRadiusMeters,
    this.estimatedRsrpDbm,
    this.downlinkEstimatedMbps,
    this.mechanicalTiltDeg,
    this.magneticDeclinationDeg,
    this.gpsAccuracyMeters,
    this.clientAltitudeMeters,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientName': clientName,
      'clientAddress': clientAddress,
      'clientLat': clientLat,
      'clientLon': clientLon,
      'towerId': towerId,
      'towerCode': towerCode,
      'towerAddress': towerAddress,
      'targetBearing': targetBearing,
      'distanceMeters': distanceMeters,
      'technologyBand': technologyBand,
      'signalRssiDbm': signalRssiDbm,
      'rsrpDbm': rsrpDbm,
      'sinrDb': sinrDb,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'fsplDb': fsplDb,
      'fresnelRadiusMeters': fresnelRadiusMeters,
      'estimatedRsrpDbm': estimatedRsrpDbm,
      'downlinkEstimatedMbps': downlinkEstimatedMbps,
      'mechanicalTiltDeg': mechanicalTiltDeg,
      'magneticDeclinationDeg': magneticDeclinationDeg,
      'gpsAccuracyMeters': gpsAccuracyMeters,
      'clientAltitudeMeters': clientAltitudeMeters,
    };
  }

  factory InstallationJob.fromMap(Map<String, dynamic> map) {
    return InstallationJob(
      id: map['id']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      clientAddress: map['clientAddress']?.toString() ?? '',
      clientLat: (map['clientLat'] as num).toDouble(),
      clientLon: (map['clientLon'] as num).toDouble(),
      towerId: map['towerId']?.toString() ?? '',
      towerCode: map['towerCode']?.toString() ?? '',
      towerAddress: map['towerAddress']?.toString() ?? '',
      targetBearing: (map['targetBearing'] as num).toDouble(),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      technologyBand: map['technologyBand']?.toString() ?? '5G n78',
      signalRssiDbm: map['signalRssiDbm'] != null ? (map['signalRssiDbm'] as num).toInt() : null,
      rsrpDbm: map['rsrpDbm'] != null ? (map['rsrpDbm'] as num).toInt() : null,
      sinrDb: map['sinrDb'] != null ? (map['sinrDb'] as num).toDouble() : null,
      notes: map['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'Alineada y completada',
      fsplDb: map['fsplDb'] != null ? (map['fsplDb'] as num).toDouble() : null,
      fresnelRadiusMeters: map['fresnelRadiusMeters'] != null ? (map['fresnelRadiusMeters'] as num).toDouble() : null,
      estimatedRsrpDbm: map['estimatedRsrpDbm'] != null ? (map['estimatedRsrpDbm'] as num).toDouble() : null,
      downlinkEstimatedMbps: map['downlinkEstimatedMbps'] != null ? (map['downlinkEstimatedMbps'] as num).toInt() : null,
      mechanicalTiltDeg: map['mechanicalTiltDeg'] != null ? (map['mechanicalTiltDeg'] as num).toDouble() : null,
      magneticDeclinationDeg: map['magneticDeclinationDeg'] != null ? (map['magneticDeclinationDeg'] as num).toDouble() : null,
      gpsAccuracyMeters: map['gpsAccuracyMeters'] != null ? (map['gpsAccuracyMeters'] as num).toDouble() : null,
      clientAltitudeMeters: map['clientAltitudeMeters'] != null ? (map['clientAltitudeMeters'] as num).toDouble() : null,
    );
  }
}
