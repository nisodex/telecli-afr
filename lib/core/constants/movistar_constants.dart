/// Official constants, frequency bands, and Minetur endpoints for Movistar AFR 5G.
class MovistarConstants {
  // Operator Identification
  static const String telefonicaOperatorName = 'TELEFONICA MOVILES ESPAÑA, S.A.U.';
  static const List<String> movistarKeywords = [
    'TELEFONICA',
    'TELEFÓNICA',
    'MOVISTAR',
    'TESAU',
    'TME'
  ];

  // Minetur VCTEL Endpoints
  static const String mineturBaseUrl = 'https://geoportal.minetur.gob.es/VCTEL';
  static const String mineturGeoJsonEndpoint = '/infoantenasGeoJSON.do';
  static const String mineturDetailEndpoint = '/detalleEstacion.do';
  static const String mineturInitEndpoint = '/vcne.do';

  // 5G & 4G Frequency Band Classifications
  static const double bandN78MinMhz = 3400.0;
  static const double bandN78MaxMhz = 3800.0; // 3.5 GHz 5G High Speed (AFR 5G Primary)

  static const double bandN28MinMhz = 700.0;
  static const double bandN28MaxMhz = 790.0;  // 700 MHz 5G Long Range

  static const double band4G800MinMhz = 791.0;
  static const double band4G800MaxMhz = 862.0;

  static const double band4G1800MinMhz = 1710.0;
  static const double band4G1800MaxMhz = 1880.0;

  static const double band4G2600MinMhz = 2500.0;
  static const double band4G2600MaxMhz = 2690.0;

  // Alignment tolerances for directional antennas
  static const double defaultAlignedToleranceDegrees = 3.0; // ±3° target window
  static const double defaultWarningToleranceDegrees = 10.0; // ±10° approaching window

  // Default search radii in kilometers
  static const List<double> searchRadiiKm = [1.0, 3.0, 5.0, 10.0, 20.0];
}
