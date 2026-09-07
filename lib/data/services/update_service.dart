import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// State of the OTA Update lifecycle.
enum UpdateState {
  idle,
  checking,
  updateAvailable,
  upToDate,
  downloading,
  readyToInstall,
  error,
}

/// Metadata model for a published application update.
class UpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final String apkUrl;
  final int? fileSizeBytes;
  final bool mandatory;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.apkUrl,
    this.fileSizeBytes,
    this.mandatory = false,
    this.publishedAt,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    // Detect GitHub Releases API response structure
    if (json.containsKey('tag_name') && json.containsKey('assets')) {
      final rawTag = json['tag_name'] as String? ?? '1.0.0';
      final cleanVersion = rawTag.replaceFirst('v', '').trim();
      final body = json['body'] as String? ?? 'Nueva versión disponible en GitHub.';
      final published = json['published_at'] != null ? DateTime.tryParse(json['published_at'] as String) : null;

      String apkUrl = '';
      int? size;
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String? ?? '';
          size = asset['size'] as int?;
          break;
        }
      }

      return UpdateInfo(
        version: cleanVersion,
        buildNumber: 1,
        releaseNotes: body,
        apkUrl: apkUrl,
        fileSizeBytes: size,
        mandatory: false,
        publishedAt: published,
      );
    }

    return UpdateInfo(
      version: (json['version'] as String? ?? '1.0.0').replaceFirst('v', '').trim(),
      buildNumber: json['buildNumber'] as int? ?? 1,
      releaseNotes: json['releaseNotes'] as String? ?? 'Mejoras de rendimiento y corrección de errores.',
      apkUrl: json['apkUrl'] as String? ?? '',
      fileSizeBytes: json['fileSizeBytes'] as int?,
      mandatory: json['mandatory'] as bool? ?? false,
      publishedAt: json['publishedAt'] != null ? DateTime.tryParse(json['publishedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'buildNumber': buildNumber,
        'releaseNotes': releaseNotes,
        'apkUrl': apkUrl,
        'fileSizeBytes': fileSizeBytes,
        'mandatory': mandatory,
        'publishedAt': publishedAt?.toIso8601String(),
      };

  /// Compares this version against the installed version.
  bool isNewerThan(String currentVersion, int currentBuildNumber) {
    final List<int> thisParts = _parseVersion(version);
    final List<int> currParts = _parseVersion(currentVersion);

    final maxLength = thisParts.length > currParts.length ? thisParts.length : currParts.length;
    for (int i = 0; i < maxLength; i++) {
      final t = i < thisParts.length ? thisParts[i] : 0;
      final c = i < currParts.length ? currParts[i] : 0;
      if (t > c) return true;
      if (t < c) return false;
    }

    return buildNumber > currentBuildNumber;
  }

  static List<int> _parseVersion(String v) {
    final clean = v.replaceFirst('v', '').split('+').first.trim();
    return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }
}

/// Service handling Over-The-Air (OTA) APK updates for Movistar AFR 5G Enterprise field terminals.
class UpdateService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('es.telecli.afr/updater');

  /// Generates a standard GitHub Releases API URL for a repository (owner/repo)
  static String gitHubLatestReleaseUrl(String owner, String repo) =>
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  // Configured update endpoint (GitHub Releases API for nisodex/telecli-afr)
  static String defaultUpdateUrl = 'https://api.github.com/repos/nisodex/telecli-afr/releases/latest';

  UpdateState _state = UpdateState.idle;
  UpdateState get state => _state;

  UpdateInfo? _availableUpdate;
  UpdateInfo? get availableUpdate => _availableUpdate;

  String _currentVersion = '1.0.0';
  String get currentVersion => _currentVersion;

  int _currentBuildNumber = 1;
  int get currentBuildNumber => _currentBuildNumber;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  String? _downloadedApkPath;
  String? get downloadedApkPath => _downloadedApkPath;

  http.Client _httpClient = http.Client();

  UpdateService({http.Client? httpClient}) {
    if (httpClient != null) _httpClient = httpClient;
    _initAppVersion();
  }

  bool _versionExplicitlySet = false;

  Future<void> _initAppVersion() async {
    if (_versionExplicitlySet) return;
    try {
      final info = await PackageInfo.fromPlatform();
      if (_versionExplicitlySet) return;
      _currentVersion = info.version;
      _currentBuildNumber = int.tryParse(info.buildNumber) ?? 1;
    } catch (_) {
      if (_versionExplicitlySet) return;
      _currentVersion = '1.0.0';
      _currentBuildNumber = 1;
    }
    notifyListeners();
  }

  /// Sets current version directly for testing or override
  void setInstalledVersion(String version, int buildNumber) {
    _versionExplicitlySet = true;
    _currentVersion = version;
    _currentBuildNumber = buildNumber;
    notifyListeners();
  }

  /// Checks if the operating system allows requesting package installs (Android 8.0+)
  Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? allowed = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return allowed ?? true;
    } catch (e) {
      debugPrint('[UpdateService] Error checking install permission: $e');
      return true;
    }
  }

  /// Navigates to Android Settings to permit unknown sources installation
  Future<void> openInstallPermissionSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('[UpdateService] Error opening permission settings: $e');
    }
  }

  /// Queries manifest for any newly released APK builds.
  Future<UpdateInfo?> checkForUpdate({String? url, bool mockUpdate = false}) async {
    _state = UpdateState.checking;
    _statusMessage = 'Comprobando actualizaciones en el servidor...';
    notifyListeners();

    await _initAppVersion();

    if (mockUpdate) {
      await Future.delayed(const Duration(milliseconds: 600));
      final simulated = UpdateInfo(
        version: '1.1.0',
        buildNumber: _currentBuildNumber + 1,
        releaseNotes: '• Descarga offline por provincias completa (SQLite).\n'
            '• Compartición rápida de boletines por WhatsApp y Email.\n'
            '• Telemetría de elevación y visor AR calibrado en tejado.\n'
            '• Sistema de auto-actualización OTA para cuadrillas.',
        apkUrl: 'https://example.com/afr5g_v1.1.0.apk',
        fileSizeBytes: 24500000,
        publishedAt: DateTime.now(),
      );

      if (simulated.isNewerThan(_currentVersion, _currentBuildNumber)) {
        _availableUpdate = simulated;
        _state = UpdateState.updateAvailable;
        _statusMessage = '¡Nueva versión ${simulated.version} disponible!';
      } else {
        _availableUpdate = null;
        _state = UpdateState.upToDate;
        _statusMessage = 'La aplicación está actualizada ($_currentVersion).';
      }
      notifyListeners();
      return _availableUpdate;
    }

    final targetUrl = url ?? defaultUpdateUrl;
    try {
      final response = await _httpClient.get(
        Uri.parse(targetUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json, application/json',
          'User-Agent': 'Movistar-AFR5G-Updater',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final update = UpdateInfo.fromJson(data);

        if (update.isNewerThan(_currentVersion, _currentBuildNumber)) {
          _availableUpdate = update;
          _state = UpdateState.updateAvailable;
          _statusMessage = 'Nueva versión ${update.version} disponible.';
        } else {
          _availableUpdate = null;
          _state = UpdateState.upToDate;
          _statusMessage = 'Dispones de la última versión instalada ($_currentVersion).';
        }
      } else {
        _state = UpdateState.upToDate;
        _statusMessage = 'Dispones de la última versión instalada ($_currentVersion).';
      }
    } catch (e) {
      debugPrint('[UpdateService] Network check fallback: $e');
      _state = UpdateState.upToDate;
      _statusMessage = 'Dispones de la versión $_currentVersion (sin conexión al servidor OTA).';
    }

    notifyListeners();
    return _availableUpdate;
  }

  /// Downloads the given APK to the app cache directory with streaming progress.
  Future<File?> downloadApk(UpdateInfo update) async {
    _state = UpdateState.downloading;
    _downloadProgress = 0.0;
    _statusMessage = 'Descargando actualización ${update.version}...';
    notifyListeners();

    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/afr5g_update_${update.version}.apk');

      // If already completely downloaded
      if (await targetFile.exists() && update.fileSizeBytes != null && await targetFile.length() == update.fileSizeBytes) {
        _downloadProgress = 1.0;
        _downloadedApkPath = targetFile.path;
        _state = UpdateState.readyToInstall;
        _statusMessage = 'Paquete listo para instalar.';
        notifyListeners();
        return targetFile;
      }

      // If downloading from a mock or offline URL
      if (update.apkUrl.startsWith('mock://') || update.apkUrl.contains('example.com')) {
        // Simulate real progress steps
        for (int i = 1; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 150));
          _downloadProgress = i / 10.0;
          _statusMessage = 'Descargando APK... ${(downloadProgress * 100).toInt()}%';
          notifyListeners();
        }
        await targetFile.writeAsBytes(utf8.encode('SIMULATED_APK_PAYLOAD_FOR_TESTING'));
        _downloadedApkPath = targetFile.path;
        _state = UpdateState.readyToInstall;
        _statusMessage = 'Descarga finalizada. Listo para instalar.';
        notifyListeners();
        return targetFile;
      }

      final request = http.Request('GET', Uri.parse(update.apkUrl));
      final response = await _httpClient.send(request);

      if (response.statusCode != 200) {
        throw Exception('Error HTTP ${response.statusCode} al descargar APK');
      }

      final totalBytes = response.contentLength ?? update.fileSizeBytes ?? 0;
      int receivedBytes = 0;

      final sink = targetFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          _statusMessage = 'Descargando: ${(receivedBytes / 1048576).toStringAsFixed(1)} MB / ${(totalBytes / 1048576).toStringAsFixed(1)} MB (${(_downloadProgress * 100).toInt()}%)';
        } else {
          _statusMessage = 'Descargando: ${(receivedBytes / 1048576).toStringAsFixed(1)} MB';
        }
        notifyListeners();
      }

      await sink.flush();
      await sink.close();

      _downloadProgress = 1.0;
      _downloadedApkPath = targetFile.path;
      _state = UpdateState.readyToInstall;
      _statusMessage = 'Descarga completada. Listo para instalar.';
      notifyListeners();
      return targetFile;
    } catch (e) {
      _state = UpdateState.error;
      _statusMessage = 'Error al descargar la actualización: $e';
      notifyListeners();
      return null;
    }
  }

  /// Triggers the Android package manager installation for the downloaded APK.
  Future<bool> installApk({String? filePath}) async {
    final path = filePath ?? _downloadedApkPath;
    if (path == null) {
      _state = UpdateState.error;
      _statusMessage = 'No se ha encontrado el archivo APK descargado.';
      notifyListeners();
      return false;
    }

    if (!Platform.isAndroid) {
      _statusMessage = 'La instalación automática sólo está disponible en dispositivos Android.';
      notifyListeners();
      return false;
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>('installApk', {'filePath': path});
      return success ?? false;
    } catch (e) {
      _state = UpdateState.error;
      _statusMessage = 'Error al ejecutar el instalador del sistema: $e';
      notifyListeners();
      return false;
    }
  }
}
