import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/movistar_constants.dart';
import '../models/tower_model.dart';
import 'local_storage_service.dart';

/// Data class representing a Spanish province with geographic boundary.
class ProvinceData {
  final String code;
  final String name;
  final List<double> bbox; // [minLon, minLat, maxLon, maxLat]

  const ProvinceData({
    required this.code,
    required this.name,
    required this.bbox,
  });
}

/// Service managing offline downloading and caching of base stations by province.
class ProvinceManagerService {
  final LocalStorageService _localStorage;
  final http.Client _client;

  ProvinceManagerService({
    LocalStorageService? localStorage,
    http.Client? client,
  })  : _localStorage = localStorage ?? LocalStorageService(),
        _client = client ?? http.Client();

  /// Standard geographic bounding boxes for Spanish provinces where Movistar AFR 5G is deployed.
  static const List<ProvinceData> provinces = [
    ProvinceData(code: 'MAD', name: 'Madrid', bbox: [-4.58, 39.88, -3.05, 41.17]),
    ProvinceData(code: 'TO', name: 'Toledo', bbox: [-5.40, 39.26, -2.97, 40.35]),
    ProvinceData(code: 'GU', name: 'Guadalajara', bbox: [-3.52, 40.40, -1.54, 41.34]),
    ProvinceData(code: 'SG', name: 'Segovia', bbox: [-4.62, 40.80, -3.27, 41.58]),
    ProvinceData(code: 'AV', name: 'Ávila', bbox: [-5.71, 40.08, -4.26, 41.18]),
    ProvinceData(code: 'CU', name: 'Cuenca', bbox: [-3.18, 39.25, -1.18, 40.78]),
    ProvinceData(code: 'CR', name: 'Ciudad Real', bbox: [-5.08, 38.38, -2.60, 39.58]),
    ProvinceData(code: 'VA', name: 'Valladolid', bbox: [-5.57, 41.10, -4.01, 42.30]),
    ProvinceData(code: 'BCN', name: 'Barcelona', bbox: [1.40, 41.20, 2.55, 42.30]),
    ProvinceData(code: 'VLC', name: 'Valencia', bbox: [-1.55, 38.65, 0.35, 40.10]),
    ProvinceData(code: 'SEV', name: 'Sevilla', bbox: [-6.55, 36.85, -4.75, 38.20]),
    ProvinceData(code: 'ZGZ', name: 'Zaragoza', bbox: [-2.20, 41.00, -0.20, 42.60]),
    ProvinceData(code: 'MAL', name: 'Málaga', bbox: [-5.60, 36.40, -3.80, 37.25]),
    ProvinceData(code: 'ALI', name: 'Alicante', bbox: [-1.05, 37.85, 0.30, 38.90]),
    ProvinceData(code: 'MUR', name: 'Murcia', bbox: [-2.35, 37.35, -0.65, 38.75]),
  ];

  /// Downloads and caches all 5G/4G stations in a province.
  /// Reports progress from 0.0 to 1.0 via [onProgress].
  Future<int> downloadProvince({
    required ProvinceData province,
    required void Function(double progress, String status) onProgress,
  }) async {
    onProgress(0.05, 'Iniciando descarga de ${province.name}...');

    // Split province bbox into a 3x3 grid to guarantee complete capture without Minetur truncation
    final minLon = province.bbox[0];
    final minLat = province.bbox[1];
    final maxLon = province.bbox[2];
    final maxLat = province.bbox[3];

    const int gridSteps = 3;
    final double stepLon = (maxLon - minLon) / gridSteps;
    final double stepLat = (maxLat - minLat) / gridSteps;

    final Map<String, TowerModel> uniqueTowers = {};
    int totalCells = gridSteps * gridSteps;
    int completedCells = 0;

    for (int i = 0; i < gridSteps; i++) {
      for (int j = 0; j < gridSteps; j++) {
        final cellMinLon = minLon + (i * stepLon);
        final cellMaxLon = cellMinLon + stepLon;
        final cellMinLat = minLat + (j * stepLat);
        final cellMaxLat = cellMinLat + stepLat;

        final bboxStr =
            '${cellMinLon.toStringAsFixed(4)},${cellMinLat.toStringAsFixed(4)},${cellMaxLon.toStringAsFixed(4)},${cellMaxLat.toStringAsFixed(4)}';

        try {
          final towers = await _fetchCellTowers(bboxStr);
          for (final t in towers) {
            uniqueTowers[t.id] = t;
          }
        } catch (e) {
          debugPrint('[ProvinceManagerService] Error in cell $bboxStr: $e');
        }

        completedCells++;
        final progress = 0.10 + (0.80 * (completedCells / totalCells));
        onProgress(
          progress,
          'Descargando ${province.name}: sector $completedCells/$totalCells (${uniqueTowers.length} antenas)',
        );
      }
    }

    onProgress(0.92, 'Guardando ${uniqueTowers.length} estaciones en base de datos local SQLite...');
    final towerList = uniqueTowers.values.toList();
    if (towerList.isNotEmpty) {
      await _localStorage.cacheTowers(towerList);
    }

    await _localStorage.saveProvinceMeta(
      code: province.code,
      name: province.name,
      towerCount: towerList.length,
    );

    onProgress(1.0, '¡Descarga completada! ${uniqueTowers.length} estaciones listas para uso offline.');
    return towerList.length;
  }

  Future<List<TowerModel>> _fetchCellTowers(String bboxStr) async {
    final queryParams = {
      'idCapa': 'null',
      'bbox': bboxStr,
      'zoom': '6',
    };

    final uri = Uri.parse('${MovistarConstants.mineturBaseUrl}${MovistarConstants.mineturGeoJsonEndpoint}')
        .replace(queryParameters: queryParams);

    final response = await _client.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Referer': '${MovistarConstants.mineturBaseUrl}${MovistarConstants.mineturInitEndpoint}',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json, text/javascript, */*',
      },
    ).timeout(const Duration(seconds: 14));

    if (response.statusCode != 200) return [];

    String bodyString;
    try {
      bodyString = latin1.decode(response.bodyBytes);
    } catch (_) {
      bodyString = utf8.decode(response.bodyBytes, allowMalformed: true);
    }

    if (bodyString.trim().isEmpty || bodyString == '{}') return [];

    final Map<String, dynamic> jsonMap = json.decode(bodyString);
    final List<dynamic> features = jsonMap['features'] as List<dynamic>? ?? [];

    final List<TowerModel> list = [];
    for (final f in features) {
      if (f is Map<String, dynamic>) {
        final tower = TowerModel.fromMineturGeoJson(f);
        if (tower.isMovistar) {
          list.add(tower);
        }
      }
    }
    return list;
  }

  /// Checks if a province has been cached
  Future<bool> isProvinceDownloaded(String code) async {
    final downloaded = await _localStorage.getDownloadedProvinces();
    return downloaded.any((p) => p['code'] == code);
  }

  /// Deletes an offline province from SQLite
  Future<void> deleteProvince(ProvinceData province) async {
    await _localStorage.deleteProvinceCache(
      code: province.code,
      bbox: province.bbox,
    );
  }
}
