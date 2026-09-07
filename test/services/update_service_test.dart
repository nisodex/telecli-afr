import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/data/services/update_service.dart';

void main() {
  group('UpdateInfo Unit Tests', () {
    test('JSON deserialization parses all attributes correctly', () {
      final json = {
        'version': '1.2.3',
        'buildNumber': 42,
        'releaseNotes': 'Notas de la versión de prueba.',
        'apkUrl': 'https://example.com/app.apk',
        'fileSizeBytes': 10485760,
        'mandatory': true,
        'publishedAt': '2026-09-07T10:00:00.000Z',
      };

      final update = UpdateInfo.fromJson(json);

      expect(update.version, equals('1.2.3'));
      expect(update.buildNumber, equals(42));
      expect(update.releaseNotes, equals('Notas de la versión de prueba.'));
      expect(update.apkUrl, equals('https://example.com/app.apk'));
      expect(update.fileSizeBytes, equals(10485760));
      expect(update.mandatory, isTrue);
      expect(update.publishedAt, isNotNull);
    });

    test('GitHub Releases API JSON deserialization extracts version and APK asset URL', () {
      final gitHubPayload = {
        'tag_name': 'v1.1.0',
        'name': 'Movistar AFR 5G Release v1.1.0',
        'body': '• Soporte offline por provincias en SQLite\n• Envío de boletines a WhatsApp',
        'published_at': '2026-09-07T13:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'size': 25800100,
            'browser_download_url': 'https://github.com/telefonica-internal/movistar-afr5g/releases/download/v1.1.0/app-release.apk',
          }
        ],
      };

      final update = UpdateInfo.fromJson(gitHubPayload);

      expect(update.version, equals('1.1.0'));
      expect(update.releaseNotes, contains('WhatsApp'));
      expect(update.apkUrl, equals('https://github.com/telefonica-internal/movistar-afr5g/releases/download/v1.1.0/app-release.apk'));
      expect(update.fileSizeBytes, equals(25800100));
      expect(update.isNewerThan('1.0.0', 1), isTrue);
      expect(update.isNewerThan('1.1.0', 1), isFalse);
    });

    test('Semantic version comparison with isNewerThan', () {
      // Test major version bump
      final updateMajor = const UpdateInfo(
        version: '2.0.0',
        buildNumber: 1,
        releaseNotes: '',
        apkUrl: '',
      );
      expect(updateMajor.isNewerThan('1.9.9', 99), isTrue);

      // Test minor version bump
      final updateMinor = const UpdateInfo(
        version: '1.2.0',
        buildNumber: 1,
        releaseNotes: '',
        apkUrl: '',
      );
      expect(updateMinor.isNewerThan('1.1.9', 10), isTrue);
      expect(updateMinor.isNewerThan('1.2.0', 1), isFalse);

      // Test patch version bump
      final updatePatch = const UpdateInfo(
        version: '1.0.1',
        buildNumber: 1,
        releaseNotes: '',
        apkUrl: '',
      );
      expect(updatePatch.isNewerThan('1.0.0', 5), isTrue);

      // Test build number bump on same version
      final updateBuild = const UpdateInfo(
        version: '1.0.0',
        buildNumber: 5,
        releaseNotes: '',
        apkUrl: '',
      );
      expect(updateBuild.isNewerThan('1.0.0', 4), isTrue);
      expect(updateBuild.isNewerThan('1.0.0', 5), isFalse);
      expect(updateBuild.isNewerThan('1.0.0', 6), isFalse);

      // Test older version
      final updateOlder = const UpdateInfo(
        version: '0.9.5',
        buildNumber: 10,
        releaseNotes: '',
        apkUrl: '',
      );
      expect(updateOlder.isNewerThan('1.0.0', 1), isFalse);
    });
  });

  group('UpdateService State Machine Tests', () {
    test('Simulated update check detects newer version', () async {
      final service = UpdateService();
      service.setInstalledVersion('1.0.0', 1);

      final update = await service.checkForUpdate(mockUpdate: true);

      expect(update, isNotNull);
      expect(service.state, equals(UpdateState.updateAvailable));
      expect(update!.version, equals('1.1.0'));
      expect(service.statusMessage, contains('1.1.0'));
    });

    test('Simulated update check marks up to date if installed version is higher', () async {
      final service = UpdateService();
      service.setInstalledVersion('2.0.0', 10);

      final update = await service.checkForUpdate(mockUpdate: true);

      expect(update, isNull);
      expect(service.state, equals(UpdateState.upToDate));
      expect(service.statusMessage, contains('actualizada'));
    });
  });
}
