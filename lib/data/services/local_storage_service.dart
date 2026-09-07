import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/utils/geo_calculator.dart';
import '../models/installation_job.dart';
import '../models/tower_model.dart';

/// SQLite persistence service for offline towers cache and installation reports.
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Database? _db;
  bool _useInMemoryFallback = false;
  final List<TowerModel> _inMemoryTowers = [];
  final List<InstallationJob> _inMemoryJobs = [];

  Future<Database?> get database async {
    if (_useInMemoryFallback) return null;
    if (_db != null) return _db!;
    try {
      _db = await _initDatabase();
      return _db;
    } catch (e) {
      debugPrint('[LocalStorageService] SQLite init failed ($e), using in-memory store');
      _useInMemoryFallback = true;
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    String dbPath;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docsDir.path, 'movistar_afr5g.db');
    } catch (_) {
      final databasesPath = await getDatabasesPath();
      dbPath = p.join(databasesPath, 'movistar_afr5g.db');
    }

    return await openDatabase(
      dbPath,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_towers (
            id TEXT PRIMARY KEY,
            code TEXT,
            operator TEXT,
            address TEXT,
            latitude REAL,
            longitude REAL,
            detailUrl TEXT,
            bands TEXT,
            has5Gn78 INTEGER,
            has5Gn28 INTEGER,
            has4G INTEGER,
            has3G INTEGER,
            has2G INTEGER,
            isMovistar INTEGER,
            radiationLevel REAL,
            sectorAzimuths TEXT,
            cachedAt INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE installation_jobs (
            id TEXT PRIMARY KEY,
            clientName TEXT,
            clientAddress TEXT,
            clientLat REAL,
            clientLon REAL,
            towerId TEXT,
            towerCode TEXT,
            towerAddress TEXT,
            targetBearing REAL,
            distanceMeters REAL,
            technologyBand TEXT,
            signalRssiDbm INTEGER,
            rsrpDbm INTEGER,
            sinrDb REAL,
            notes TEXT,
            createdAt TEXT,
            status TEXT,
            fsplDb REAL,
            fresnelRadiusMeters REAL,
            estimatedRsrpDbm REAL,
            downlinkEstimatedMbps INTEGER,
            mechanicalTiltDeg REAL,
            magneticDeclinationDeg REAL,
            gpsAccuracyMeters REAL,
            clientAltitudeMeters REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE provinces_cache_meta (
            code TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            towerCount INTEGER NOT NULL,
            lastUpdatedMs INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final columns = [
            'ALTER TABLE installation_jobs ADD COLUMN fsplDb REAL',
            'ALTER TABLE installation_jobs ADD COLUMN fresnelRadiusMeters REAL',
            'ALTER TABLE installation_jobs ADD COLUMN estimatedRsrpDbm REAL',
            'ALTER TABLE installation_jobs ADD COLUMN downlinkEstimatedMbps INTEGER',
            'ALTER TABLE installation_jobs ADD COLUMN mechanicalTiltDeg REAL',
            'ALTER TABLE installation_jobs ADD COLUMN magneticDeclinationDeg REAL',
            'ALTER TABLE installation_jobs ADD COLUMN gpsAccuracyMeters REAL',
            'ALTER TABLE installation_jobs ADD COLUMN clientAltitudeMeters REAL',
          ];
          for (final query in columns) {
            try {
              await db.execute(query);
            } catch (_) {}
          }
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS provinces_cache_meta (
              code TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              towerCount INTEGER NOT NULL,
              lastUpdatedMs INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE cached_towers ADD COLUMN has3G INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE cached_towers ADD COLUMN has2G INTEGER DEFAULT 0');
          } catch (_) {}
        }
      },
    );
  }

  /// Caches a list of towers to SQLite or in-memory fallback
  Future<void> cacheTowers(List<TowerModel> towers) async {
    try {
      final db = await database;
      if (db == null) {
        for (final t in towers) {
          _inMemoryTowers.removeWhere((item) => item.id == t.id);
          _inMemoryTowers.add(t);
        }
        return;
      }
      final batch = db.batch();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (final t in towers) {
        final map = t.toMap();
        map['cachedAt'] = nowMs;
        batch.insert('cached_towers', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[LocalStorageService] cacheTowers error: $e');
    }
  }

  /// Queries towers within a radius [radiusKm] of [lat, lon]
  Future<List<TowerModel>> getTowersInRadius({
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    try {
      final db = await database;
      if (db == null) {
        final List<TowerModel> list = [];
        for (final tower in _inMemoryTowers) {
          final dist = GeoCalculator.calculateDistanceMeters(lat, lon, tower.latitude, tower.longitude);
          if (dist <= radiusKm * 1000) {
            tower.distanceMeters = dist;
            tower.azimuthBearing = GeoCalculator.calculateBearing(lat, lon, tower.latitude, tower.longitude);
            list.add(tower);
          }
        }
        list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        return list;
      }
      final bbox = GeoCalculator.calculateBbox(lat, lon, radiusKm);

      final List<Map<String, dynamic>> results = await db.query(
        'cached_towers',
        where: 'longitude >= ? AND longitude <= ? AND latitude >= ? AND latitude <= ?',
        whereArgs: [bbox[0], bbox[2], bbox[1], bbox[3]],
      );

      final List<TowerModel> list = [];
      for (final map in results) {
        final tower = TowerModel.fromMap(map);
        tower.distanceMeters = GeoCalculator.calculateDistanceMeters(lat, lon, tower.latitude, tower.longitude);
        tower.azimuthBearing = GeoCalculator.calculateBearing(lat, lon, tower.latitude, tower.longitude);
        list.add(tower);
      }

      list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return list;
    } catch (e) {
      debugPrint('[LocalStorageService] getTowersInRadius error: $e');
      return [];
    }
  }

  /// Inserts a new installation report
  Future<void> saveJob(InstallationJob job) async {
    try {
      final db = await database;
      if (db == null) {
        _inMemoryJobs.removeWhere((j) => j.id == job.id);
        _inMemoryJobs.insert(0, job);
        return;
      }
      await db.insert('installation_jobs', job.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('[LocalStorageService] saveJob error: $e');
    }
  }

  /// Retrieves all saved installation reports sorted by newest first
  Future<List<InstallationJob>> getAllJobs() async {
    try {
      final db = await database;
      if (db == null) {
        return List.from(_inMemoryJobs);
      }
      final List<Map<String, dynamic>> results = await db.query(
        'installation_jobs',
        orderBy: 'createdAt DESC',
      );
      return results.map((m) => InstallationJob.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[LocalStorageService] getAllJobs error: $e');
      return [];
    }
  }

  /// Deletes a saved job by ID
  Future<void> deleteJob(String id) async {
    try {
      final db = await database;
      if (db == null) {
        _inMemoryJobs.removeWhere((j) => j.id == id);
        return;
      }
      await db.delete('installation_jobs', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[LocalStorageService] deleteJob error: $e');
    }
  }

  /// Records or updates offline cache metadata for a province
  Future<void> saveProvinceMeta({
    required String code,
    required String name,
    required int towerCount,
  }) async {
    try {
      final db = await database;
      if (db == null) return;
      await db.insert(
        'provinces_cache_meta',
        {
          'code': code,
          'name': name,
          'towerCount': towerCount,
          'lastUpdatedMs': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[LocalStorageService] saveProvinceMeta error: $e');
    }
  }

  /// Returns all provinces downloaded for offline use
  Future<List<Map<String, dynamic>>> getDownloadedProvinces() async {
    try {
      final db = await database;
      if (db == null) return [];
      return await db.query('provinces_cache_meta', orderBy: 'name ASC');
    } catch (e) {
      debugPrint('[LocalStorageService] getDownloadedProvinces error: $e');
      return [];
    }
  }

  /// Deletes a province cache and removes its towers from SQLite
  Future<void> deleteProvinceCache({
    required String code,
    required List<double> bbox,
  }) async {
    try {
      final db = await database;
      if (db == null) return;
      await db.delete('provinces_cache_meta', where: 'code = ?', whereArgs: [code]);
      await db.delete(
        'cached_towers',
        where: 'longitude >= ? AND longitude <= ? AND latitude >= ? AND latitude <= ?',
        whereArgs: [bbox[0], bbox[2], bbox[1], bbox[3]],
      );
    } catch (e) {
      debugPrint('[LocalStorageService] deleteProvinceCache error: $e');
    }
  }

  /// Gets the total number of cached towers currently stored in SQLite
  Future<int> getTotalCachedTowersCount() async {
    try {
      final db = await database;
      if (db == null) return _inMemoryTowers.length;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM cached_towers');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('[LocalStorageService] getTotalCachedTowersCount error: $e');
      return 0;
    }
  }
}
