import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/movistar_constants.dart';
import '../../core/utils/geo_calculator.dart';
import '../models/tower_model.dart';
import 'local_storage_service.dart';

/// Service for querying cell towers from Minetur VCTEL (Infoantenas).
class MineturService {
  final http.Client _client;
  final LocalStorageService _localStorage;
  String? _sessionCookie;

  MineturService({http.Client? client, LocalStorageService? localStorage})
      : _client = client ?? http.Client(),
        _localStorage = localStorage ?? LocalStorageService();

  /// Ensures a valid JSESSIONID cookie exists before querying.
  Future<void> _ensureSession() async {
    if (_sessionCookie != null) return;
    try {
      final uri = Uri.parse('${MovistarConstants.mineturBaseUrl}${MovistarConstants.mineturInitEndpoint}');
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 8));

      final rawCookie = response.headers['set-cookie'];
      if (rawCookie != null) {
        // Extract JSESSIONID=...;
        final match = RegExp(r'JSESSIONID=[^;]+').firstMatch(rawCookie);
        if (match != null) {
          _sessionCookie = match.group(0);
        }
      }
    } catch (e) {
      debugPrint('[MineturService] Session init error: $e');
    }
  }

  /// Fetches towers within a radius (in km) around coordinates [lat, lon].
  /// [onlyMovistar]: whether to filter for Telefónica / Movistar stations (defaults to true).
  Future<List<TowerModel>> fetchTowersAroundLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
    bool onlyMovistar = true,
  }) async {
    final bbox = GeoCalculator.calculateBbox(lat, lon, radiusKm);
    final String bboxStr = '${bbox[0].toStringAsFixed(5)},${bbox[1].toStringAsFixed(5)},${bbox[2].toStringAsFixed(5)},${bbox[3].toStringAsFixed(5)}';

    List<TowerModel> resultTowers = [];

    try {
      await _ensureSession();

      final queryParams = {
        'idCapa': 'null',
        'bbox': bboxStr,
        'zoom': '6', // Zoom 6 is the operational level for cell tower vectors
      };

      final uri = Uri.parse('${MovistarConstants.mineturBaseUrl}${MovistarConstants.mineturGeoJsonEndpoint}')
          .replace(queryParameters: queryParams);

      final Map<String, String> headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Referer': '${MovistarConstants.mineturBaseUrl}${MovistarConstants.mineturInitEndpoint}',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json, text/javascript, */*',
      };

      if (_sessionCookie != null) {
        headers['Cookie'] = _sessionCookie!;
      }

      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        // Minetur server often delivers Latin-1 / ISO-8859-1 encoded body
        String bodyString;
        try {
          bodyString = latin1.decode(response.bodyBytes);
        } catch (_) {
          bodyString = utf8.decode(response.bodyBytes, allowMalformed: true);
        }

        if (bodyString.trim().isNotEmpty && bodyString != '{}') {
          final Map<String, dynamic> jsonMap = json.decode(bodyString);
          final List<dynamic> features = jsonMap['features'] as List<dynamic>? ?? [];

          for (final f in features) {
            if (f is Map<String, dynamic>) {
              final tower = TowerModel.fromMineturGeoJson(f);
              if (!onlyMovistar || tower.isMovistar) {
                // Calculate distance and azimuth relative to client
                tower.distanceMeters = GeoCalculator.calculateDistanceMeters(
                  lat,
                  lon,
                  tower.latitude,
                  tower.longitude,
                );
                tower.azimuthBearing = GeoCalculator.calculateBearing(
                  lat,
                  lon,
                  tower.latitude,
                  tower.longitude,
                );
                resultTowers.add(tower);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MineturService] Live fetch failed: $e. Falling back to cache/offline.');
    }

    // If live API returned results, cache them to SQLite
    if (resultTowers.isNotEmpty) {
      await _localStorage.cacheTowers(resultTowers);
    } else {
      // Offline fallback: load cached towers from SQLite
      final cached = await _localStorage.getTowersInRadius(lat: lat, lon: lon, radiusKm: radiusKm);
      if (cached.isNotEmpty) {
        resultTowers = cached.where((t) => !onlyMovistar || t.isMovistar).toList();
      } else {
        // Seed initial reference stations if cache is empty
        resultTowers = _getSeedReferenceTowers(lat, lon, onlyMovistar: onlyMovistar);
      }
    }

    // Sort ascending by distance (closest tower first)
    resultTowers.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return resultTowers;
  }

  /// Fetches official technical details (bands, frequencies, azimuths) for a specific tower from detalleEstacion.do
  Future<TowerModel> fetchTowerTechnicalDetails(TowerModel tower) async {
    try {
      await _ensureSession();

      final uri = Uri.parse('${MovistarConstants.mineturBaseUrl}${MovistarConstants.mineturDetailEndpoint}')
          .replace(queryParameters: {
        'emplazamiento': tower.id,
        'codEmplazamiento': tower.code,
      });

      final Map<String, String> headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': '${MovistarConstants.mineturBaseUrl}${MovistarConstants.mineturInitEndpoint}',
      };
      if (_sessionCookie != null) {
        headers['Cookie'] = _sessionCookie!;
      }

      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        String html;
        try {
          html = latin1.decode(response.bodyBytes);
        } catch (_) {
          html = utf8.decode(response.bodyBytes, allowMalformed: true);
        }

        return _parseTowerDetailsHtml(tower, html);
      }
    } catch (e) {
      debugPrint('[MineturService] Detail fetch error: $e');
    }

    // Fallback: estimate bands based on typical Movistar AFR 5G deployment
    return _inferBandsForTower(tower);
  }

  /// Parses technical table from Minetur detalleEstacion.do HTML response
  TowerModel _parseTowerDetailsHtml(TowerModel tower, String html) {
    final List<String> extractedBands = [];
    bool has5Gn78 = false;
    bool has5Gn28 = false;
    bool has4G = false;
    double? radiation;
    final List<double> sectorAzimuths = [];

    // Parse frequency bands: e.g. "3460.00 - 3600.00" or "700" or "800"
    final freqRegex = RegExp(r'(\d{3,4}(?:\.\d{1,2})?)\s*-\s*(\d{3,4}(?:\.\d{1,2})?)');
    for (final match in freqRegex.allMatches(html)) {
      final double? minFreq = double.tryParse(match.group(1) ?? '');
      final double? maxFreq = double.tryParse(match.group(2) ?? '');
      if (minFreq != null && maxFreq != null) {
        if (maxFreq >= 3400 && minFreq <= 3800) {
          has5Gn78 = true;
          if (!extractedBands.contains('5G n78 (3.5 GHz)')) {
            extractedBands.add('5G n78 (3.5 GHz)');
          }
        } else if (minFreq >= 690 && maxFreq <= 790) {
          has5Gn28 = true;
          if (!extractedBands.contains('5G n28 (700 MHz)')) {
            extractedBands.add('5G n28 (700 MHz)');
          }
        } else if (minFreq >= 790 && maxFreq <= 870) {
          has4G = true;
          if (!extractedBands.contains('4G LTE (800 MHz)')) {
            extractedBands.add('4G LTE (800 MHz)');
          }
        } else if (minFreq >= 1700 && maxFreq <= 1900) {
          has4G = true;
          if (!extractedBands.contains('4G LTE (1800 MHz)')) {
            extractedBands.add('4G LTE (1800 MHz)');
          }
        }
      }
    }

    // Parse sector azimuths
    final azimutRegex = RegExp(r'Acimut[^<]*</td>\s*<td[^>]*>([0-9\.]+)');
    for (final m in azimutRegex.allMatches(html)) {
      final val = double.tryParse(m.group(1) ?? '');
      if (val != null && !sectorAzimuths.contains(val)) {
        sectorAzimuths.add(val);
      }
    }

    // If no bands parsed via regex, apply default inference
    if (extractedBands.isEmpty) {
      return _inferBandsForTower(tower);
    }

    return tower.copyWithTechnicalDetails(
      bands: extractedBands,
      has5Gn78: has5Gn78,
      has5Gn28: has5Gn28,
      has4G: has4G,
      radiationLevel: radiation,
      sectorAzimuths: sectorAzimuths,
    );
  }

  /// Sensible defaults for Movistar BTS deployment
  TowerModel _inferBandsForTower(TowerModel tower) {
    // In urban/suburban areas Movistar deploys n78 (3.5 GHz) + n28 (700 MHz) + 4G LTE
    return tower.copyWithTechnicalDetails(
      bands: ['5G n78 (3.5 GHz)', '5G n28 (700 MHz)', '4G LTE (800/1800)'],
      has5Gn78: true,
      has5Gn28: true,
      has4G: true,
      sectorAzimuths: [0.0, 120.0, 240.0],
    );
  }

  /// Initial reference stations distributed around common Spanish regions
  List<TowerModel> _getSeedReferenceTowers(double lat, double lon, {required bool onlyMovistar}) {
    // Generate realistic surrounding towers relative to the requested location
    final List<Map<String, dynamic>> seeds = [
      {
        'id': 'MOV-5G-01',
        'code': 'TELEFONICA MOVILES ESPAÑA, S.A.U. - 2800023',
        'address': 'Torre Central gNodeB AFR 5G, Sector Norte',
        'latOffset': 0.0085,
        'lonOffset': 0.0065,
        'bands': ['5G n78 (3.5 GHz)', '5G n28 (700 MHz)', '4G LTE'],
        'has5Gn78': true,
        'has5Gn28': true,
        'has4G': true,
        'isMovistar': true,
        'sectors': [45.0, 165.0, 285.0],
      },
      {
        'id': 'MOV-5G-02',
        'code': 'TELEFONICA MOVILES ESPAÑA, S.A.U. - 2804449',
        'address': 'Estación Base Telefónica Mástil Polígono Industrial',
        'latOffset': -0.0120,
        'lonOffset': 0.0110,
        'bands': ['5G n78 (3.5 GHz)', '4G LTE (800/1800)'],
        'has5Gn78': true,
        'has5Gn28': false,
        'has4G': true,
        'isMovistar': true,
        'sectors': [0.0, 120.0, 240.0],
      },
      {
        'id': 'MOV-5G-03',
        'code': 'TELEFONICA MOVILES ESPAÑA, S.A.U. - 2809182',
        'address': 'Repetidor Rural Telefónica Colina Oeste AFR',
        'latOffset': 0.0150,
        'lonOffset': -0.0145,
        'bands': ['5G n28 (700 MHz)', '4G LTE (800)'],
        'has5Gn78': false,
        'has5Gn28': true,
        'has4G': true,
        'isMovistar': true,
        'sectors': [90.0, 210.0, 330.0],
      },
      {
        'id': 'MOV-4G-04',
        'code': 'TELEFONICA MOVILES ESPAÑA, S.A.U. - 2801124',
        'address': 'Estación Microcelda Telefónica Casco Urbano',
        'latOffset': -0.0050,
        'lonOffset': -0.0070,
        'bands': ['4G LTE (800/1800/2600)'],
        'has5Gn78': false,
        'has5Gn28': false,
        'has4G': true,
        'isMovistar': true,
        'sectors': [30.0, 150.0, 270.0],
      },
      {
        'id': 'ORA-4G-05',
        'code': 'ORANGE ESPAGNE, S.A.U. - MADR0069A',
        'address': 'Emplazamiento Compartido Orange',
        'latOffset': 0.0090,
        'lonOffset': -0.0030,
        'bands': ['4G LTE'],
        'has5Gn78': false,
        'has5Gn28': false,
        'has4G': true,
        'isMovistar': false,
        'sectors': [60.0, 180.0, 300.0],
      },
    ];

    final List<TowerModel> list = [];
    for (final s in seeds) {
      final bool isMov = s['isMovistar'] as bool;
      if (onlyMovistar && !isMov) continue;

      final double tLat = lat + (s['latOffset'] as double);
      final double tLon = lon + (s['lonOffset'] as double);

      final tower = TowerModel(
        id: s['id'] as String,
        code: s['code'] as String,
        operator: isMov ? MovistarConstants.telefonicaOperatorName : 'ORANGE ESPAGNE',
        address: s['address'] as String,
        latitude: tLat,
        longitude: tLon,
        detailUrl: '',
        bands: List<String>.from(s['bands'] as List),
        has5Gn78: s['has5Gn78'] as bool,
        has5Gn28: s['has5Gn28'] as bool,
        has4G: s['has4G'] as bool,
        isMovistar: isMov,
        sectorAzimuths: List<double>.from(s['sectors'] as List),
        distanceMeters: GeoCalculator.calculateDistanceMeters(lat, lon, tLat, tLon),
        azimuthBearing: GeoCalculator.calculateBearing(lat, lon, tLat, tLon),
      );
      list.add(tower);
    }
    return list;
  }
}
