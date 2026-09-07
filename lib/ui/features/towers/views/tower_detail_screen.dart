import 'package:flutter/material.dart';
import 'package:telecli_afr/core/di/service_locator.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';
import 'package:telecli_afr/core/utils/rf_calculator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/ui/core/widgets/rf_calculator_sheet.dart';
import 'package:telecli_afr/ui/features/alignment/views/compass_alignment_screen.dart';
import '../view_models/tower_detail_view_model.dart';

/// Full Minetur Technical Sheet Screen for a cell tower.
class TowerDetailScreen extends StatefulWidget {
  final TowerModel tower;
  final double? clientLat;
  final double? clientLon;
  final TowerDetailViewModel? viewModel;

  const TowerDetailScreen({
    super.key,
    required this.tower,
    this.clientLat,
    this.clientLon,
    this.viewModel,
  });

  @override
  State<TowerDetailScreen> createState() => _TowerDetailScreenState();
}

class _TowerDetailScreenState extends State<TowerDetailScreen> {
  late final TowerDetailViewModel _viewModel;
  late final bool _isLocalViewModel;

  @override
  void initState() {
    super.initState();
    _isLocalViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? ServiceLocator.createTowerDetailViewModel(widget.tower);
    _viewModel.fetchTechnicalDetails();
  }

  @override
  void dispose() {
    if (_isLocalViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final tower = _viewModel.tower;
        final isLoading = _viewModel.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ficha Técnica Minetur'),
          ),
          body: isLoading
              ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Consultando expediente oficial VCTEL...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cell_tower, color: AppColors.primary, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tower.operator,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                  Text(
                                    'Código: ${tower.code}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: AppColors.outline),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem('Distancia', GeoCalculator.formatDistance(tower.distanceMeters)),
                            _buildSummaryItem('Azimut', '${tower.azimuthBearing.toStringAsFixed(0)}° (${GeoCalculator.bearingToCardinal(tower.azimuthBearing)})'),
                            _buildSummaryItem('Elevación', '${tower.elevationTilt.toStringAsFixed(1)}°'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location Information
                  _buildSectionTitle('LOCALIZACIÓN OFICIAL'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Dirección', tower.address),
                          const SizedBox(height: 10),
                          _buildDetailRow('Coordenadas', '${tower.latitude.toStringAsFixed(6)}, ${tower.longitude.toStringAsFixed(6)}'),
                          const SizedBox(height: 10),
                          _buildDetailRow('Sistema de Referencia', 'ETRS89 / EPSG:4258 (Minetur)'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Radio Frequencies & Bands
                  _buildSectionTitle('CARACTERÍSTICAS RADIO Y BANDAS'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tower.has5Gn78)
                            _buildBandBadge(
                              '5G n78 (3.5 GHz) - Banda Óptima Movistar AFR 5G',
                              'Frecuencia: 3400 - 3800 MHz • Gigabits FWA',
                              AppColors.accent5G,
                            ),
                          if (tower.has5Gn28) ...[
                            const SizedBox(height: 8),
                            _buildBandBadge(
                              '5G n28 (700 MHz) - Banda Cobertura Rural',
                              'Frecuencia: 703 - 788 MHz • Penetración alta',
                              AppColors.accent5GLow,
                            ),
                          ],
                          if (tower.has4G) ...[
                            const SizedBox(height: 8),
                            _buildBandBadge(
                              '4G LTE (800 / 1800 / 2600 MHz)',
                              'Banda de respaldo telefónica LTE-A',
                              AppColors.accent4G,
                            ),
                          ],
                          if (tower.has3G) ...[
                            const SizedBox(height: 8),
                            _buildBandBadge(
                              '3G UMTS / WCDMA (900 / 2100 MHz)',
                              'Banda de voz y datos móviles 3G',
                              AppColors.accent3G,
                            ),
                          ],
                          if (tower.has2G) ...[
                            const SizedBox(height: 8),
                            _buildBandBadge(
                              '2G GSM / GPRS / EDGE (900 / 1800 MHz)',
                              'Banda básica de telefonía móvil y telemetría',
                              AppColors.accent2G,
                            ),
                          ],
                          if (tower.bands.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Bandas registradas en Minetur:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: tower.bands.map((b) => Chip(
                                label: Text(b, style: const TextStyle(fontSize: 11)),
                                backgroundColor: AppColors.surfaceVariant,
                                side: const BorderSide(color: AppColors.outline),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sector Azimuths if available
                  if (tower.sectorAzimuths.isNotEmpty) ...[
                    _buildSectionTitle('ACIMUTS DE SECTORES DECLARADOS'),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: tower.sectorAzimuths.map((az) {
                            return Column(
                              children: [
                                const Icon(Icons.radar, color: AppColors.primary, size: 22),
                                const SizedBox(height: 4),
                                Text('${az.toStringAsFixed(0)}°', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(GeoCalculator.bearingToCardinal(az), style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // RF Engineering & Mechanical Installation Parameters
                  _buildSectionTitle('INGENIERÍA DE ENLACE Y PARÁMETROS DE INSTALACIÓN'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PÉRDIDA ESPACIO LIBRE', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                  Text(
                                    '${RfCalculator.calculateFspl(tower.distanceMeters, tower.has5Gn78 ? RfCalculator.freq5Gn78Mhz : RfCalculator.freq5Gn28Mhz).toStringAsFixed(1)} dB',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('1ª ZONA FRESNEL (r₁)', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                  Text(
                                    '${RfCalculator.calculateFresnelRadius(tower.distanceMeters, tower.has5Gn78 ? RfCalculator.freq5Gn78Mhz : RfCalculator.freq5Gn28Mhz).toStringAsFixed(2)} m',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('RSRP TEÓRICO', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                  Text(
                                    '${RfCalculator.estimateRsrp(distanceMeters: tower.distanceMeters, isN78: tower.has5Gn78).toStringAsFixed(0)} dBm',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accent5G),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: AppColors.outline),
                          const SizedBox(height: 10),

                          _buildDetailRow('Antena Exterior', tower.has5Gn78 ? 'Unidad ODU Panel Directiva (11.5 dBi)' : 'Panel Dual 700/800 MHz (8.5 dBi)'),
                          const SizedBox(height: 8),
                          _buildDetailRow('Throughput Estimado', '${RfCalculator.estimateDownlinkThroughput(rsrpDbm: RfCalculator.estimateRsrp(distanceMeters: tower.distanceMeters, isN78: tower.has5Gn78), isN78: tower.has5Gn78)} Mbps Downlink'),
                          const SizedBox(height: 8),
                          _buildDetailRow('Mástil Recomendado', 'Diámetro exterior 40-50 mm (Acero galvanizado)'),
                          const SizedBox(height: 8),
                          _buildDetailRow('Par de Apriete', '12 - 15 Nm (Tornillería métrica M8/M10 inox)'),
                          const SizedBox(height: 8),
                          _buildDetailRow('Puesta a Tierra', 'Conductor Cu ≥ 16 mm² a red equipotencial'),
                          const SizedBox(height: 14),

                          OutlinedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => Padding(
                                  padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                                  child: RfCalculatorSheet(tower: tower),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calculate, size: 18),
                            label: const Text('ABRIR CALCULADORA / SIMULADOR RF'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 42),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action CTA button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompassAlignmentScreen(
                            tower: tower,
                            clientLat: widget.clientLat ?? tower.latitude,
                            clientLon: widget.clientLon ?? tower.longitude,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.explore),
                    label: const Text('ORIENTAR ANTENA A ESTA TORRE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tower.has5Gn78 ? AppColors.accent5G : AppColors.primary,
                      foregroundColor: tower.has5Gn78 ? Colors.black : Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildBandBadge(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_tethering, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
