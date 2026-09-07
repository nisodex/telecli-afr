import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/movistar_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/geo_calculator.dart';
import '../../data/models/tower_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/minetur_service.dart';
import 'compass_alignment_screen.dart';
import 'tower_detail_screen.dart';

/// Interactive Map showing technician position, cell towers, line-of-sight laser, and coverage radius.
class MapScreen extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final List<TowerModel> towers;
  final TowerModel? selectedTower;
  final Function(TowerModel)? onTowerSelected;

  const MapScreen({
    super.key,
    required this.initialLat,
    required this.initialLon,
    this.towers = const [],
    this.selectedTower,
    this.onTowerSelected,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final MineturService _mineturService = MineturService();
  final LocationService _locationService = LocationService();

  late double _clientLat;
  late double _clientLon;
  List<TowerModel> _towers = [];
  TowerModel? _selectedTower;
  double _searchRadiusKm = 5.0;
  bool _isLoading = false;
  bool _onlyMovistar = true;
  String _addressText = '';

  @override
  void initState() {
    super.initState();
    final Position? cachedPos = LocationService.lastPosition;
    if ((widget.initialLat == LocationService.defaultLat) && cachedPos != null) {
      _clientLat = cachedPos.latitude;
      _clientLon = cachedPos.longitude;
    } else {
      _clientLat = widget.initialLat;
      _clientLon = widget.initialLon;
    }
    _towers = List.from(widget.towers);
    _selectedTower = widget.selectedTower ?? (_towers.isNotEmpty ? _towers.first : null);

    if (_towers.isEmpty) {
      _loadTowers();
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool locationChanged = widget.initialLat != oldWidget.initialLat ||
        widget.initialLon != oldWidget.initialLon;
    final bool towersChanged = widget.towers != oldWidget.towers;
    final bool selectionChanged = widget.selectedTower != oldWidget.selectedTower;

    if (locationChanged || towersChanged || selectionChanged) {
      setState(() {
        _clientLat = widget.initialLat;
        _clientLon = widget.initialLon;
        if (widget.towers.isNotEmpty) {
          _towers = List.from(widget.towers);
        }
        _selectedTower = widget.selectedTower ?? (_towers.isNotEmpty ? _towers.first : null);
      });

      if (locationChanged) {
        _mapController.move(LatLng(_clientLat, _clientLon), 14.5);
      }
      if (_towers.isEmpty && locationChanged) {
        _loadTowers();
      }
    }
  }

  Future<void> _loadTowers() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _mineturService.fetchTowersAroundLocation(
        lat: _clientLat,
        lon: _clientLon,
        radiusKm: _searchRadiusKm,
        onlyMovistar: _onlyMovistar,
      );

      _addressText = await _locationService.reverseGeocode(_clientLat, _clientLon);

      if (mounted) {
        setState(() {
          _towers = fetched;
          if (_selectedTower != null) {
            _selectedTower = _towers.firstWhere(
              (t) => t.id == _selectedTower!.id,
              orElse: () => _towers.isNotEmpty ? _towers.first : _selectedTower!,
            );
          } else if (_towers.isNotEmpty) {
            _selectedTower = _towers.first;
          }
        });
      }
    } catch (e) {
      debugPrint('[MapScreen] Error loading towers: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recenterGps() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      setState(() {
        _clientLat = pos.latitude;
        _clientLon = pos.longitude;
      });
      _mapController.move(LatLng(_clientLat, _clientLon), 14.5);
      await _loadTowers();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientLatLng = LatLng(_clientLat, _clientLon);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Torres Minetur'),
        actions: [
          IconButton(
            icon: Icon(
              _onlyMovistar ? Icons.filter_alt : Icons.filter_alt_off,
              color: _onlyMovistar ? AppColors.primary : Colors.white,
            ),
            tooltip: _onlyMovistar ? 'Mostrando sólo Movistar' : 'Mostrando todos los operadores',
            onPressed: () {
              setState(() {
                _onlyMovistar = !_onlyMovistar;
              });
              _loadTowers();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar torres Minetur',
            onPressed: _loadTowers,
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
              onTap: (_, point) {
                // If technician taps anywhere on map, allow moving client pin or deselecting
              },
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
                    radius: _searchRadiusKm * 1000,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderColor: AppColors.primary.withValues(alpha: 0.4),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

              // Line of Sight (LOS) Laser Beam to Selected Tower
              if (_selectedTower != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        clientLatLng,
                        LatLng(_selectedTower!.latitude, _selectedTower!.longitude),
                      ],
                      strokeWidth: 3.5,
                      color: _selectedTower!.has5Gn78 ? AppColors.accent5G : AppColors.primary,
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
                  ..._towers.map((tower) {
                    final bool isSel = _selectedTower?.id == tower.id;
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
                          setState(() {
                            _selectedTower = tower;
                          });
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
                                  final bool isSel = _searchRadiusKm == r;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() => _searchRadiusKm = r);
                                        _loadTowers();
                                      },
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
                      if (_isLoading) ...[
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
            bottom: _selectedTower != null ? 240 : 20,
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
          if (_selectedTower != null)
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
                      color: _selectedTower!.has5Gn78 ? AppColors.accent5G : AppColors.primary,
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
                              _selectedTower!.operator,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (_selectedTower!.has5Gn78
                                      ? AppColors.accent5G
                                      : _selectedTower!.has5Gn28
                                          ? AppColors.accent5GLow
                                          : _selectedTower!.has4G
                                              ? AppColors.accent4G
                                              : _selectedTower!.has3G
                                                  ? AppColors.accent3G
                                                  : _selectedTower!.has2G
                                                      ? AppColors.accent2G
                                                      : AppColors.accentOther)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _selectedTower!.has5Gn78
                                    ? AppColors.accent5G
                                    : _selectedTower!.has5Gn28
                                        ? AppColors.accent5GLow
                                        : _selectedTower!.has4G
                                            ? AppColors.accent4G
                                            : _selectedTower!.has3G
                                                ? AppColors.accent3G
                                                : _selectedTower!.has2G
                                                    ? AppColors.accent2G
                                                    : AppColors.accentOther,
                              ),
                            ),
                            child: Text(
                              _selectedTower!.has5Gn78
                                  ? 'AFR 5G (n78)'
                                  : _selectedTower!.has5Gn28
                                      ? '5G (n28)'
                                      : _selectedTower!.has4G
                                          ? '4G LTE'
                                          : _selectedTower!.has3G
                                              ? '3G UMTS'
                                              : _selectedTower!.has2G
                                                  ? '2G GSM'
                                                  : 'MÓVIL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _selectedTower!.has5Gn78
                                    ? AppColors.accent5G
                                    : _selectedTower!.has5Gn28
                                        ? AppColors.accent5GLow
                                        : _selectedTower!.has4G
                                            ? AppColors.accent4G
                                            : _selectedTower!.has3G
                                                ? AppColors.accent3G
                                                : _selectedTower!.has2G
                                                    ? AppColors.accent2G
                                                    : AppColors.accentOther,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedTower!.address,
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricChip(
                            'DISTANCIA',
                            GeoCalculator.formatDistance(_selectedTower!.distanceMeters),
                            Icons.straighten,
                          ),
                          _buildMetricChip(
                            'AZIMUT',
                            '${_selectedTower!.azimuthBearing.toStringAsFixed(0)}° (${GeoCalculator.bearingToCardinal(_selectedTower!.azimuthBearing)})',
                            Icons.explore,
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
                                      tower: _selectedTower!,
                                      clientLat: _clientLat,
                                      clientLon: _clientLon,
                                      clientAddress: _addressText,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.explore),
                              label: const Text('ORIENTAR ANTENA'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedTower!.has5Gn78 ? AppColors.accent5G : AppColors.primary,
                                foregroundColor: _selectedTower!.has5Gn78 ? Colors.black : Colors.white,
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
                                  builder: (context) => TowerDetailScreen(tower: _selectedTower!),
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
  }

  Widget _buildMetricChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}
