import 'package:flutter/material.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/services/location_service.dart';
import 'package:telecli_afr/ui/core/widgets/offline_provinces_modal.dart';
import 'package:telecli_afr/ui/core/widgets/tower_card.dart';
import 'package:telecli_afr/ui/features/alignment/views/compass_alignment_screen.dart';
import '../view_models/tower_list_view_model.dart';
import 'tower_detail_screen.dart';

/// Screen listing cell towers sorted by proximity with filters for 5G bands.
/// Conforms to MVVM architecture consuming TowerListViewModel.
class TowerListScreen extends StatefulWidget {
  final double clientLat;
  final double clientLon;
  final List<TowerModel> initialTowers;
  final TowerListViewModel? viewModel;

  const TowerListScreen({
    super.key,
    required this.clientLat,
    required this.clientLon,
    this.initialTowers = const [],
    this.viewModel,
  });

  @override
  State<TowerListScreen> createState() => _TowerListScreenState();
}

class _TowerListScreenState extends State<TowerListScreen> {
  late final TowerListViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? TowerListViewModel();

    final double effectiveLat = (widget.clientLat == LocationService.defaultLat && LocationService.lastPosition != null)
        ? LocationService.lastPosition!.latitude
        : widget.clientLat;
    final double effectiveLon = (widget.clientLon == LocationService.defaultLon && LocationService.lastPosition != null)
        ? LocationService.lastPosition!.longitude
        : widget.clientLon;

    if (widget.initialTowers.isNotEmpty) {
      _viewModel.initializeWithTowers(widget.initialTowers);
    } else {
      _viewModel.loadTowersForLocation(
        clientLat: effectiveLat,
        clientLon: effectiveLon,
      );
    }
  }

  @override
  void didUpdateWidget(TowerListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool locationChanged = widget.clientLat != oldWidget.clientLat ||
        widget.clientLon != oldWidget.clientLon;
    final bool towersChanged = widget.initialTowers != oldWidget.initialTowers;

    if (towersChanged && widget.initialTowers.isNotEmpty) {
      _viewModel.initializeWithTowers(widget.initialTowers);
    } else if (locationChanged) {
      _viewModel.loadTowersForLocation(
        clientLat: widget.clientLat,
        clientLon: widget.clientLon,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final filteredTowers = _viewModel.filteredTowers;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Censo Minetur / Estaciones'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_for_offline_outlined, color: AppColors.primary),
                tooltip: 'Descargas offline (Provincias)',
                onPressed: () => OfflineProvincesModal.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar censo',
                onPressed: () => _viewModel.loadTowersForLocation(
                  clientLat: widget.clientLat,
                  clientLon: widget.clientLon,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Search & Filter header container
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                color: AppColors.surface,
                child: Column(
                  children: [
                    // Search box
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => _viewModel.setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: 'Buscar por dirección, código o torre...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _viewModel.setSearchQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.outline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter chips row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('5G n78 (3.5 GHz)', '5G n78', AppColors.accent5G),
                          const SizedBox(width: 8),
                          _buildFilterChip('5G n28 (700 MHz)', '5G n28', AppColors.accent5GLow),
                          const SizedBox(width: 8),
                          _buildFilterChip('4G LTE', '4G LTE', AppColors.accent4G),
                          const SizedBox(width: 8),
                          _buildFilterChip('3G UMTS', '3G UMTS', AppColors.accent3G),
                          const SizedBox(width: 8),
                          _buildFilterChip('2G GSM', '2G GSM', AppColors.accent2G),
                          const SizedBox(width: 8),
                          _buildFilterChip('Solo Movistar', 'Movistar', AppColors.primary),
                          const SizedBox(width: 8),
                          _buildFilterChip('Todas las operadoras', 'Todas', AppColors.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Count summary bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.background,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Torres encontradas: ${filteredTowers.length}',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const Text(
                      'Ordenado por distancia',
                      style: TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                  ],
                ),
              ),

              // Tower list
              Expanded(
                child: _viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : filteredTowers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cell_tower, size: 48, color: AppColors.outline),
                                const SizedBox(height: 12),
                                const Text(
                                  'No se encontraron torres con los filtros seleccionados',
                                  style: TextStyle(color: AppColors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _viewModel.setFilter('Todas');
                                    _viewModel.setSearchQuery('');
                                  },
                                  child: const Text('Ver todas las torres'),
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isWide = constraints.maxWidth >= 720.0;

                              Widget buildCard(TowerModel tower) {
                                return TowerCard(
                                  key: ValueKey(tower.id),
                                  tower: tower,
                                  onSelect: () {},
                                  onAlign: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CompassAlignmentScreen(
                                          tower: tower,
                                          clientLat: widget.clientLat,
                                          clientLon: widget.clientLon,
                                          clientAddress: _viewModel.addressText,
                                        ),
                                      ),
                                    );
                                  },
                                  onDetails: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TowerDetailScreen(
                                          tower: tower,
                                          clientLat: widget.clientLat,
                                          clientLon: widget.clientLon,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }

                              return RefreshIndicator(
                                onRefresh: () => _viewModel.loadTowersForLocation(
                                  clientLat: widget.clientLat,
                                  clientLon: widget.clientLon,
                                ),
                                color: AppColors.primary,
                                child: isWide
                                    ? GridView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 540,
                                          mainAxisExtent: 260,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                        ),
                                        itemCount: filteredTowers.length,
                                        itemBuilder: (context, index) => buildCard(filteredTowers[index]),
                                      )
                                    : ListView.builder(
                                        itemCount: filteredTowers.length,
                                        itemBuilder: (context, index) => buildCard(filteredTowers[index]),
                                      ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final bool isSelected = _viewModel.selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.25),
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide(color: isSelected ? color : AppColors.outline),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? color : AppColors.onSurfaceVariant,
      ),
      onSelected: (_) => _viewModel.setFilter(value),
    );
  }
}
