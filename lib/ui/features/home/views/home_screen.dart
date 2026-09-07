import 'package:flutter/material.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';
import 'package:telecli_afr/core/utils/rf_calculator.dart';
import 'package:telecli_afr/ui/core/widgets/app_update_modal.dart';
import 'package:telecli_afr/ui/core/widgets/rf_calculator_sheet.dart';
import 'package:telecli_afr/ui/features/alignment/views/ar_view_screen.dart';
import 'package:telecli_afr/ui/features/alignment/views/compass_alignment_screen.dart';
import '../view_models/home_view_model.dart';

/// Technician Home Dashboard for Movistar AFR 5G Field Operations.
/// Conforms to MVVM architecture consuming HomeViewModel.
class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateTab;
  final HomeViewModel? viewModel;

  const HomeScreen({
    super.key,
    required this.onNavigateTab,
    this.viewModel,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? HomeViewModel();
    _viewModel.initLocationAndTowers();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TELECLI',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('AFR 5G'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.system_update_alt_rounded),
                tooltip: 'Actualizaciones del Terminal',
                onPressed: () => AppUpdateModal.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.my_location),
                tooltip: 'Actualizar GPS',
                onPressed: () => _viewModel.initLocationAndTowers(),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth >= 800.0;

              return RefreshIndicator(
                onRefresh: () => _viewModel.initLocationAndTowers(),
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: GPS & Recommended Tower
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildClientGpsCard(),
                                      const SizedBox(height: 16),
                                      _buildBestTowerCard(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Right Column: Tools, RF Sim & Field Stats
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildToolsSection(),
                                      const SizedBox(height: 16),
                                      _buildStatsCard(),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildClientGpsCard(),
                                const SizedBox(height: 16),
                                _buildBestTowerCard(),
                                const SizedBox(height: 20),
                                _buildToolsSection(),
                                const SizedBox(height: 20),
                                _buildStatsCard(),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'HERRAMIENTAS DE ORIENTACIÓN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                title: 'Brújula HUD',
                subtitle: 'Alineación precisa',
                icon: Icons.explore,
                color: AppColors.primary,
                onTap: () {
                  final bestTower = _viewModel.best5gTower;
                  if (bestTower != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CompassAlignmentScreen(
                          tower: bestTower,
                          clientLat: _viewModel.lat,
                          clientLon: _viewModel.lon,
                          clientAddress: _viewModel.address,
                        ),
                      ),
                    );
                  } else {
                    widget.onNavigateTab(2); // Compass tab
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToolCard(
                title: 'Cámara AR',
                subtitle: 'Línea de visión real',
                icon: Icons.camera_alt,
                color: AppColors.accent5G,
                onTap: () {
                  final bestTower = _viewModel.best5gTower;
                  if (bestTower != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArViewScreen(
                          tower: bestTower,
                          clientLat: _viewModel.lat,
                          clientLon: _viewModel.lon,
                          clientAltitude: _viewModel.currentPosition?.altitude ?? 644.0,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Selecciona una torre primero')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                title: 'Mapa Cobertura',
                subtitle: 'Ver torres y láser',
                icon: Icons.map,
                color: AppColors.accent5GLow,
                onTap: () => widget.onNavigateTab(1), // Map tab
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToolCard(
                title: 'Censo Minetur',
                subtitle: '${_viewModel.towers.length} torres cercanas',
                icon: Icons.cell_tower,
                color: AppColors.accent4G,
                onTap: () => widget.onNavigateTab(3), // Tower list tab
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildToolCardWide(
          title: 'Calculadora de Enlace RF',
          subtitle: 'Simulación de pérdidas de cable, ganancia y RSRP',
          icon: Icons.calculate,
          color: AppColors.primary,
          onTap: () {
            final bestTower = _viewModel.best5gTower;
            if (bestTower != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                  child: RfCalculatorSheet(tower: bestTower),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buscando torres para el cálculo...')),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildClientGpsCard() {
    final pos = _viewModel.currentPosition;
    final lat = _viewModel.lat;
    final lon = _viewModel.lon;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'UBICACIÓN DEL CLIENTE (GPS)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
                  ),
                ],
              ),
              if (_viewModel.isLoadingGps)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.alignedGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('GPS OK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.alignedGreen)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _viewModel.address,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${lat.toStringAsFixed(6)} N, ${lon.toStringAsFixed(6)} W',
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.height, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Altitud: ${pos != null ? '${pos.altitude.toStringAsFixed(0)}m' : '650m'}',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed, size: 14, color: AppColors.accent5G),
                    const SizedBox(width: 4),
                    Text(
                      'Precisión: ±${pos != null ? pos.accuracy.toStringAsFixed(1) : '3.0'}m',
                      style: const TextStyle(fontSize: 11, color: AppColors.accent5G, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation, size: 14, color: AppColors.accent5GLow),
                    const SizedBox(width: 4),
                    Text(
                      'Decl: ${RfCalculator.estimateMagneticDeclination(lat, lon).toStringAsFixed(1)}°',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestTowerCard() {
    if (_viewModel.isLoadingTowers) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 10),
              Text('Localizando torres Movistar 5G...', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final t = _viewModel.best5gTower;
    if (t == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentWarning),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accentWarning, size: 36),
            const SizedBox(height: 8),
            const Text(
              'No se detectaron torres 5G en 5 km',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Amplía el radio en la pestaña Censo Minetur.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => widget.onNavigateTab(3), // Tower List tab
              child: const Text('BUSCAR EN TODAS LAS TORRES'),
            ),
          ],
        ),
      );
    }

    final Color bestColor = t.has5Gn78
        ? AppColors.accent5G
        : t.has5Gn28
            ? AppColors.accent5GLow
            : t.has4G
                ? AppColors.accent4G
                : t.has3G
                    ? AppColors.accent3G
                    : t.has2G
                        ? AppColors.accent2G
                        : AppColors.primary;

    final String badgeLabel = t.has5Gn78
        ? '⭐ RECOMENDADA PARA AFR 5G'
        : t.has5Gn28
            ? 'COBERTURA 5G DISPONIBLE'
            : t.has4G
                ? 'COBERTURA 4G LTE'
                : t.has3G
                    ? 'COBERTURA 3G UMTS'
                    : t.has2G
                        ? 'COBERTURA 2G GSM'
                        : 'ESTACIÓN BASE';

    final String bandLabel = t.has5Gn78
        ? '3.5 GHz'
        : t.has5Gn28
            ? '700 MHz'
            : t.has4G
                ? '4G LTE'
                : t.has3G
                    ? '3G UMTS'
                    : t.has2G
                        ? '2G GSM'
                        : 'Móvil';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bestColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: bestColor.withValues(alpha: 0.12),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bestColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: bestColor,
                  ),
                ),
              ),
              Text(
                GeoCalculator.formatDistance(t.distanceMeters),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.address,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.explore, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Rumbo: ${t.azimuthBearing.toStringAsFixed(0)}° (${GeoCalculator.bearingToCardinal(t.azimuthBearing)})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bandLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: bestColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTowerRfMetric(
                    'FSPL',
                    '${RfCalculator.calculateFspl(t.distanceMeters, t.has5Gn78 ? RfCalculator.freq5Gn78Mhz : RfCalculator.freq5Gn28Mhz).toStringAsFixed(1)} dB',
                    Colors.white70,
                  ),
                ),
                Expanded(
                  child: _buildTowerRfMetric(
                    'RSRP Est.',
                    '${RfCalculator.estimateRsrp(distanceMeters: t.distanceMeters, isN78: t.has5Gn78).toStringAsFixed(0)} dBm',
                    AppColors.accent5G,
                  ),
                ),
                Expanded(
                  child: _buildTowerRfMetric(
                    '1ª Fresnel',
                    '${RfCalculator.calculateFresnelRadius(t.distanceMeters, t.has5Gn78 ? RfCalculator.freq5Gn78Mhz : RfCalculator.freq5Gn28Mhz).toStringAsFixed(1)} m',
                    AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildTowerRfMetric(
                    'Downlink',
                    '~${RfCalculator.estimateDownlinkThroughput(rsrpDbm: RfCalculator.estimateRsrp(distanceMeters: t.distanceMeters, isN78: t.has5Gn78), isN78: t.has5Gn78)}M',
                    Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CompassAlignmentScreen(
                    tower: t,
                    clientLat: _viewModel.lat,
                    clientLon: _viewModel.lon,
                    clientAddress: _viewModel.address,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.explore),
            label: const Text('ORIENTAR ANTENA AHORA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.has5Gn78 ? AppColors.accent5G : AppColors.primary,
              foregroundColor: t.has5Gn78 ? Colors.black : Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final int n78Count = _viewModel.towers.where((t) => t.has5Gn78).length;
    final int n28Count = _viewModel.towers.where((t) => t.has5Gn28).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCol('Torres Movistar', _viewModel.towers.length.toString(), AppColors.primary),
          ),
          Expanded(
            child: _buildStatCol('5G n78 (3.5 GHz)', n78Count.toString(), AppColors.accent5G),
          ),
          Expanded(
            child: _buildStatCol('5G n28 (700 MHz)', n28Count.toString(), AppColors.accent5GLow),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTowerRfMetric(String label, String value, [Color color = Colors.white]) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildToolCardWide({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
