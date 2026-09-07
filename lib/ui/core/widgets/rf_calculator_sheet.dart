import 'package:flutter/material.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/rf_calculator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';

/// Interactive RF Link Calculator Bottom Sheet for Field Technicians.
class RfCalculatorSheet extends StatefulWidget {
  final TowerModel tower;

  const RfCalculatorSheet({super.key, required this.tower});

  @override
  State<RfCalculatorSheet> createState() => _RfCalculatorSheetState();
}

class _RfCalculatorSheetState extends State<RfCalculatorSheet> {
  late double _distanceMeters;
  late bool _isN78;
  double _antennaGainDbi = 11.5; // Standard Movistar AFR 5G outdoor unit
  double _cableLengthMeters = 5.0;
  bool _isCat6aEthernet = true; // Ethernet PoE vs coaxial
  double _mountHeightMeters = 3.0; // Typical rooftop mast height

  @override
  void initState() {
    super.initState();
    _distanceMeters = widget.tower.distanceMeters > 0 ? widget.tower.distanceMeters : 400.0;
    _isN78 = widget.tower.has5Gn78;
    if (!_isN78) _antennaGainDbi = 8.5;
  }

  @override
  Widget build(BuildContext context) {
    final double freqMhz = _isN78 ? RfCalculator.freq5Gn78Mhz : RfCalculator.freq5Gn28Mhz;
    final double cableLossDb = _isCat6aEthernet ? 0.2 : (_cableLengthMeters * 0.18); // Coaxial has higher RF loss

    final double fsplDb = RfCalculator.calculateFspl(_distanceMeters, freqMhz);
    final double fresnelR1 = RfCalculator.calculateFresnelRadius(_distanceMeters, freqMhz);
    final double clearance60 = RfCalculator.calculateFresnel60PercentClearance(_distanceMeters, freqMhz);

    final double estimatedRsrp = RfCalculator.estimateRsrp(
      distanceMeters: _distanceMeters,
      isN78: _isN78,
      customAntennaGainDbi: _antennaGainDbi,
      cableLossDb: cableLossDb,
    );

    final int estimatedSpeed = RfCalculator.estimateDownlinkThroughput(
      rsrpDbm: estimatedRsrp,
      isN78: _isN78,
    );

    // Fade margin relative to minimum operational threshold (-105 dBm)
    final double fadeMargin = (estimatedRsrp - (-105.0)).clamp(0.0, 50.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calculate, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Calculadora de Enlace RF',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Simulación de propagación para: ${widget.tower.code}',
              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Live Performance Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResultItem('RSRP ESTIMADO', '${estimatedRsrp.toStringAsFixed(1)} dBm', AppColors.accent5G),
                  _buildResultItem('THROUGHPUT', '$estimatedSpeed Mbps', Colors.white),
                  _buildResultItem('MARGEN ENLACE', '+${fadeMargin.toStringAsFixed(1)} dB', AppColors.alignedGreen),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Technology Selector Chip
            const Text(
              'BANDA DE FRECUENCIA 5G',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('5G n78 (3.5 GHz • FWA High)'),
                  selected: _isN78,
                  selectedColor: AppColors.accent5G.withValues(alpha: 0.25),
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: _isN78 ? AppColors.accent5G : AppColors.onSurfaceVariant,
                    fontWeight: _isN78 ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _isN78 = true;
                        _antennaGainDbi = 11.5;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('5G n28 (700 MHz)'),
                  selected: !_isN78,
                  selectedColor: AppColors.accent5GLow.withValues(alpha: 0.25),
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: !_isN78 ? AppColors.accent5GLow : AppColors.onSurfaceVariant,
                    fontWeight: !_isN78 ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _isN78 = false;
                        _antennaGainDbi = 8.5;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Antenna Gain Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ganancia de Antena Exterior:', style: TextStyle(fontSize: 12, color: Colors.white)),
                Text('${_antennaGainDbi.toStringAsFixed(1)} dBi', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            Slider(
              value: _antennaGainDbi,
              min: 6.0,
              max: 22.0,
              divisions: 32,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _antennaGainDbi = v),
            ),

            // Distance to Tower Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Distancia a la Estación Base:', style: TextStyle(fontSize: 12, color: Colors.white)),
                Text('${_distanceMeters.toStringAsFixed(0)} m', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            Slider(
              value: _distanceMeters.clamp(50.0, 5000.0),
              min: 50.0,
              max: 5000.0,
              divisions: 99,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _distanceMeters = v),
            ),

            // Cable length & type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Longitud de Cable Exterior:', style: TextStyle(fontSize: 12, color: Colors.white)),
                Text('${_cableLengthMeters.toStringAsFixed(0)} m', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            Slider(
              value: _cableLengthMeters,
              min: 1.0,
              max: 30.0,
              divisions: 29,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _cableLengthMeters = v),
            ),
            Row(
              children: [
                Checkbox(
                  value: _isCat6aEthernet,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isCat6aEthernet = v ?? true),
                ),
                const Text('Cable Ethernet Cat 6A PoE (Pérdida RF despreciable)', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
            // Mast height slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Altura de Mástil / Soporte:', style: TextStyle(fontSize: 12, color: Colors.white)),
                Text('${_mountHeightMeters.toStringAsFixed(1)} m', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            Slider(
              value: _mountHeightMeters,
              min: 1.0,
              max: 12.0,
              divisions: 22,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _mountHeightMeters = v),
            ),
            const SizedBox(height: 8),

            // Engineering details section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildDetailLine('Pérdida en Espacio Libre (FSPL)', '${fsplDb.toStringAsFixed(1)} dB'),
                  const SizedBox(height: 6),
                  _buildDetailLine('Radio 1ª Zona Fresnel (r₁)', '${fresnelR1.toStringAsFixed(2)} m'),
                  const SizedBox(height: 6),
                  _buildDetailLine('Despeje mínimo recomendado (60%)', '${clearance60.toStringAsFixed(2)} m'),
                  const SizedBox(height: 6),
                  _buildDetailLine('Pérdidas de cable estimadas', '${cableLossDb.toStringAsFixed(2)} dB'),
                  const SizedBox(height: 6),
                  _buildDetailLine('Altura de Montaje Mástil', '${_mountHeightMeters.toStringAsFixed(1)} m sobre tejado'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Close button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.primary,
              ),
              child: const Text('APLICAR EN ORIENTACIÓN'),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildResultItem(String title, String val, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildDetailLine(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
