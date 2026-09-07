import 'package:flutter/material.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/data/models/tower_model.dart';
import 'package:telecli_afr/data/services/location_service.dart';
import 'package:telecli_afr/ui/features/alignment/views/compass_alignment_screen.dart';
import 'package:telecli_afr/ui/features/home/view_models/home_view_model.dart';
import 'package:telecli_afr/ui/features/home/views/home_screen.dart';
import 'package:telecli_afr/ui/features/jobs/views/saved_jobs_screen.dart';
import 'package:telecli_afr/ui/features/map/views/map_screen.dart';
import 'package:telecli_afr/ui/features/towers/views/tower_list_screen.dart';

/// Responsive shell container adapting between BottomNavigationBar (Mobile) and NavigationRail (Tablet / Desktop / Landscape).
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final HomeViewModel _homeViewModel = HomeViewModel();

  double _clientLat = LocationService.lastPosition?.latitude ?? LocationService.defaultLat;
  double _clientLon = LocationService.lastPosition?.longitude ?? LocationService.defaultLon;
  List<TowerModel> _towers = [];
  TowerModel? _selectedTower;

  static const double kExpandedBreakpoint = 720.0;

  @override
  void initState() {
    super.initState();
    _homeViewModel.addListener(_onHomeViewModelChanged);
    _homeViewModel.initLocationAndTowers();
  }

  void _onHomeViewModelChanged() {
    if (mounted) {
      setState(() {
        _clientLat = _homeViewModel.lat;
        _clientLon = _homeViewModel.lon;
        _towers = _homeViewModel.towers;
        if (_selectedTower == null || !_towers.any((t) => t.id == _selectedTower!.id)) {
          _selectedTower = _homeViewModel.best5gTower ?? (_towers.isNotEmpty ? _towers.first : null);
        }
      });
    }
  }

  @override
  void dispose() {
    _homeViewModel.removeListener(_onHomeViewModelChanged);
    _homeViewModel.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(
        onNavigateTab: _onTabTapped,
        viewModel: _homeViewModel,
      ),
      MapScreen(
        initialLat: _clientLat,
        initialLon: _clientLon,
        towers: _towers,
        selectedTower: _selectedTower,
        onTowerSelected: (t) => setState(() => _selectedTower = t),
      ),
      _selectedTower != null
          ? CompassAlignmentScreen(
              tower: _selectedTower!,
              clientLat: _clientLat,
              clientLon: _clientLon,
            )
          : const Center(
              child: Text(
                'Selecciona una torre en el mapa o lista para alinear',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ),
      TowerListScreen(
        clientLat: _clientLat,
        clientLon: _clientLon,
        initialTowers: _towers,
      ),
      const SavedJobsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isExpanded = constraints.maxWidth >= kExpandedBreakpoint;

        if (isExpanded) {
          // Large screen / tablet / landscape: Side NavigationRail + Expanded content
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onTabTapped,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AFR 5G',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home, color: AppColors.primary),
                      label: Text('Inicio'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map, color: AppColors.primary),
                      label: Text('Mapa'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.explore_outlined),
                      selectedIcon: Icon(Icons.explore, color: AppColors.primary),
                      label: Text('Brújula'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.cell_tower_outlined),
                      selectedIcon: Icon(Icons.cell_tower, color: AppColors.primary),
                      label: Text('Torres'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment, color: AppColors.primary),
                      label: Text('Obras'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.outline),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          );
        }

        // Compact mobile screen: Bottom NavigationBar
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppColors.primary),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map, color: AppColors.primary),
                label: 'Mapa',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore, color: AppColors.primary),
                label: 'Brújula',
              ),
              NavigationDestination(
                icon: Icon(Icons.cell_tower_outlined),
                selectedIcon: Icon(Icons.cell_tower, color: AppColors.primary),
                label: 'Torres',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment, color: AppColors.primary),
                label: 'Obras',
              ),
            ],
          ),
        );
      },
    );
  }
}
