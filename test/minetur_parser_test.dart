import 'package:flutter_test/flutter_test.dart';
import 'package:telecli_afr/data/models/tower_model.dart';

void main() {
  group('Minetur VCTEL Parser Tests', () {
    test('Correctly parses Minetur GeoJSON feature for Telefónica station', () {
      final sampleFeature = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [-3.701703, 40.420672]
        },
        'properties': {
          'Gis_Latitud': '40.420672',
          'Gis_Longitud': '-3.701703',
          'Gis_ID': '2800023',
          'Gis_Etiqueta': 'Estación de telefonía móvil',
          'Gis_Estilo': 'vcne.estaciones',
          'Gis_Codigo': 'TELEFONICA MOVILES ESPAÑA, S.A.U. - 2800023',
          'Tipo': 'Estación de telefonía móvil',
          'Código': 'TELEFONICA MOVILES ESPAÑA, S.A.U. - 2800023',
          'Dirección': 'CL GRAN VIA, 28. MADRID, MADRID',
          'Detalle': '@@<url-aplicacion>/detalleEstacion.do?emplazamiento=2800023&codEmplazamiento=TELEFONICA MOVILES ESPAÑA, S.A.U. - 2800023'
        }
      };

      final tower = TowerModel.fromMineturGeoJson(sampleFeature);

      expect(tower.id, equals('2800023'));
      expect(tower.code, contains('2800023'));
      expect(tower.isMovistar, isTrue);
      expect(tower.operator, contains('TELEFONICA'));
      expect(tower.address, equals('CL GRAN VIA, 28. MADRID, MADRID'));
      expect(tower.latitude, closeTo(40.420672, 0.0001));
      expect(tower.longitude, closeTo(-3.701703, 0.0001));
    });

    test('Correctly identifies non-Movistar stations', () {
      final orangeFeature = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [-3.704878, 40.41761]
        },
        'properties': {
          'Gis_ID': 'MADR0069A',
          'Gis_Codigo': 'ORANGE ESPAGNE, S.A.U. - MADR0069A',
          'Código': 'ORANGE ESPAGNE, S.A.U. - MADR0069A',
          'Dirección': 'CL PRECIADOS, 3. MADRID, MADRID',
        }
      };

      final tower = TowerModel.fromMineturGeoJson(orangeFeature);
      expect(tower.isMovistar, isFalse);
      expect(tower.operator, contains('ORANGE'));
    });

    test('SQLite serialization and deserialization of TowerModel', () {
      final original = TowerModel(
        id: '2800023',
        code: 'TELEFONICA MOVILES ESPAÑA, S.A.U. - 2800023',
        operator: 'TELEFONICA MOVILES ESPAÑA, S.A.U.',
        address: 'CL GRAN VIA, 28. MADRID',
        latitude: 40.420672,
        longitude: -3.701703,
        detailUrl: '/detalle.do',
        bands: ['5G n78 (3.5 GHz)', '5G n28 (700 MHz)'],
        has5Gn78: true,
        has5Gn28: true,
        has4G: true,
        isMovistar: true,
        sectorAzimuths: [0.0, 120.0, 240.0],
      );

      final map = original.toMap();
      final restored = TowerModel.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.has5Gn78, isTrue);
      expect(restored.has5Gn28, isTrue);
      expect(restored.isMovistar, isTrue);
      expect(restored.sectorAzimuths.length, equals(3));
      expect(restored.sectorAzimuths[1], equals(120.0));
    });
  });
}
