import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:telecli_afr/core/constants/movistar_constants.dart';
import 'package:telecli_afr/core/di/service_locator.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/ui/features/alignment/views/compass_alignment_screen.dart';
import 'package:telecli_afr/ui/features/towers/views/tower_detail_screen.dart';
import '../view_models/map_view_model.dart';

/// Interactive Map showing technician position, cell towers, line-of-sight laser, and coverage radius.
/// Architected cleanly with MVVM consuming MapViewModel.
class MapScreen extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final List<TowerModel> towers;
  final TowerModel? selectedTower;
  final Function(TowerModel)? onTowerSelected;
  final MapViewModel? viewModel;

  const MapScreen({
    super.key,
    required this.initialLat,
    required this.initialLon,
    this.towers = const [],
    this.selectedTower,
    this.onTowerSelected,
    this.viewModel,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late final MapViewModel _viewModel;
  late final bool _isLocalViewModel;

  @override
  void initState() {
    super.initState();
    _isLocalViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? ServiceLocator.createMapViewModel();
    _viewModel.initialize(
      initialLat: widget.initialLat,
      initialLon: widget.initialLon,
      initialTowers: widget.towers,
      initialSelectedTower: widget.selectedTower,
    );
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool locationChanged = widget.initialLat != oldWidget.initialLat ||
        widget.initialLon != oldWidget.initialLon;
    final bool towersChanged = widget.towers != oldWidget.towers;
    final bool selectionChanged = widget.selectedTower != oldWidget.selectedTower;

    if (locationChanged || towersChanged || selectionChanged) {
      _viewModel.updateLocationAndTowers(
        lat: widget.initialLat,
        lon: widget.initialLon,
        towers: widget.towers,
        selectedTower: widget.selectedTower,
      );

      if (locationChanged) {
        _mapController.move(LatLng(widget.initialLat, widget.initialLon), 14.5);
      }
    }
  }

  @override
  void dispose() {
    if (_isLocalViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  Future<void> _recenterGps() async {
    await _viewModel.recenterGps();
    if (mounted) {
      _mapController.move(LatLng(_viewModel.clientLat, _viewModel.clientLon), 14.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final clientLatLng = LatLng(_viewModel.clientLat, _viewModel.clientLon);
        final towers = _viewModel.towers;
        final selectedTower = _viewModel.selectedTower;
        final searchRadiusKm = _viewModel.searchRadiusKm;
        final isLoading = _viewModel.isLoading;
        final onlyMovistar = _viewModel.onlyMovistar;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mapa de Torres Minetur'),
            actions: [
              IconButton(
                icon: Icon(
                  onlyMovistar ? Icons.filter_alt : Icons.filter_alt_off,
                  color: onlyMovistar ? AppColors.primary : Colors.white,
                ),
                tooltip: onlyMovistar ? 'Mostrando sólo Movistar' : 'Mostrando todos los operadores',
                onPressed: _viewModel.toggleOnlyMovistar,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar torres Minetur',
                onPressed: _viewModel.loadTowers,
              ),
            ],
          ),
          body: Stack(
            children: [
              // 1. FlutterMap with Dark / Satellite cartography
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: clientLatLng,
                  initialZoom: 14.2,
                  minZoom: 6.0,
                  maxZoom: 18.0,
                  onTap: (_, point) {},
                ),
                children: [
                  // OpenStreetMap tile layer (clean, open access without key watermark)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'es.telecli.afr',
                  ),

                  // Search radius circle
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: clientLatLng,
                        radius: searchRadiusKm * 1000,
                        useRadiusInMeter: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderColor: AppColors.primary.withValues(alpha: 0.4),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),

                  // Line of Sight (LOS) Laser Beam to Selected Tower
                  if (selectedTower != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            clientLatLng,
                            LatLng(selectedTower.latitude, selectedTower.longitude),
                          ],
                          strokeWidth: 3.5,
                          color: selectedTower.has5Gn78 ? AppColors.accent5G : AppColors.primary,
                          pattern: StrokePattern.dashed(segments: const [12, 6]),
                        ),
                      ],
                    ),

                  // Markers layer (Client + Towers)
                  MarkerLayer(
                    markers: [
                      // Client Location Marker
                      Marker(
                        point: clientLatLng,
                        width: 50,
                        height: 50,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.home, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),

                      // Towers Markers
                      ...towers.map((tower) {
                        final bool isSel = selectedTower?.id == tower.id;
                        final Color markerColor = tower.has5Gn78
                            ? AppColors.accent5G
                            : tower.has5Gn28
                                ? AppColors.accent5GLow
                                : tower.has4G
                                    ? AppColors.accent4G
                                    : tower.has3G
                                        ? AppColors.accent3G
                                        : tower.has2G
                                            ? AppColors.accent2G
                                            : AppColors.accentOther;

                        return Marker(
                          point: LatLng(tower.latitude, tower.longitude),
                          width: isSel ? 60 : 44,
                          height: isSel ? 60 : 44,
                          child: GestureDetector(
                            onTap: () {
                              _viewModel.selectTower(tower);
                              widget.onTowerSelected?.call(tower);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSel ? markerColor : AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.white : markerColor,
                                  width: isSel ? 3.0 : 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: markerColor.withValues(alpha: isSel ? 0.6 : 0.25),
                                    blurRadius: isSel ? 12 : 6,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.cell_tower,
                                size: isSel ? 28 : 20,
                                color: isSel ? Colors.black : markerColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              // 2. Top Bar: Radius filter chips & Progress indicator
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.radar, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Radio:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: MovistarConstants.searchRadiiKm.map((r) {
                                      final bool isSel = searchRadiusKm == r;
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: InkWell(
                                          onTap: () => _viewModel.setSearchRadius(r),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isSel ? AppColors.primary : AppColors.surfaceVariant,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${r.toStringAsFixed(0)}km',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                                color: isSel ? Colors.white : AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isLoading) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              minHeight: 2,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Floating Recenter GPS Button
              Positioned(
                right: 16,
                bottom: selectedTower != null ? 240 : 20,
                child: FloatingActionButton.small(
                  heroTag: 'gps_fab',
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.outline),
                  ),
                  onPressed: _recenterGps,
                  child: const Icon(Icons.my_location),
                ),
              ),

              // 4. Bottom Selected Tower Inspection Card
              if (selectedTower != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selectedTower.has5Gn78 ? AppColors.accent5G : AppColors.primary,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  selectedTower.operator,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (selectedTower.has5Gn78
                                          ? AppColors.accent5G
                                          : selectedTower.has5Gn28
                                              ? AppColors.accent5GLow
                                              : selectedTower.has4G
                                                  ? AppColors.accent4G
                                                  : selectedTower.has3G
                                                      ? AppColors.accent3G
                                                      : selectedTower.has2G
                                                          ? AppColors.accent2G
                                                          : AppColors.accentOther)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: selectedTower.has5Gn78
                                        ? AppColors.accent5G
                                        : selectedTower.has5Gn28
                                            ? AppColors.accent5GLow
                                            : selectedTower.has4G
                                                ? AppColors.accent4G
                                                : selectedTower.has3G
                                                    ? AppColors.accent3G
                                                    : selectedTower.has2G
                                                        ? AppColors.accent2G
                                                        : AppColors.accentOther,
                                  ),
                                ),
                                child: Text(
                                  selectedTower.has5Gn78
                                      ? 'AFR 5G (n78)'
                                      : selectedTower.has5Gn28
                                          ? '5G (n28)'
                                          : selectedTower.has4G
                                              ? '4G LTE'
                                              : selectedTower.has3G
                                                  ? '3G UMTS'
                                                  : selectedTower.has2G
                                                      ? '2G GSM'
                                                      : 'MÓVIL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: selectedTower.has5Gn78
                                        ? AppColors.accent5G
                                        : selectedTower.has5Gn28
                                            ? AppColors.accent5GLow
                                            : selectedTower.has4G
                                                ? AppColors.accent4G
                                                : selectedTower.has3G
                                                    ? AppColors.accent3G
                                                    : selectedTower.has2G
                                                        ? AppColors.accent2G
                                                        : AppColors.accentOther,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            selectedTower.address,
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricChip(
                                  'DISTANCIA',
                                  GeoCalculator.formatDistance(selectedTower.distanceMeters),
                                  Icons.straighten,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetricChip(
                                  'AZIMUT',
                                  '${selectedTower.azimuthBearing.toStringAsFixed(0)}° (${GeoCalculator.bearingToCardinal(selectedTower.azimuthBearing)})',
                                  Icons.explore,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CompassAlignmentScreen(
                                          tower: selectedTower,
                                          clientLat: _viewModel.clientLat,
                                          clientLon: _viewModel.clientLon,
                                          clientAddress: _viewModel.addressText,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.explore),
                                  label: const Text('ORIENTAR ANTENA'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedTower.has5Gn78 ? AppColors.accent5G : AppColors.primary,
                                    foregroundColor: selectedTower.has5Gn78 ? Colors.black : Colors.white,
                                    minimumSize: const Size(double.infinity, 48),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.info_outline),
                                tooltip: 'Ficha Minetur',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TowerDetailScreen(tower: selectedTower),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
