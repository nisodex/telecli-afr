import 'package:flutter/material.dart';
import 'package:telecli_afr/core/di/service_locator.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/data/services/local_storage_service.dart';
import 'package:telecli_afr/data/services/province_manager_service.dart';

/// Modal dialog allowing technicians to download and manage entire Spanish provinces in local SQLite.
class OfflineProvincesModal extends StatefulWidget {
  final ProvinceManagerService? manager;
  final LocalStorageService? localStorage;

  const OfflineProvincesModal({
    super.key,
    this.manager,
    this.localStorage,
  });

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const OfflineProvincesModal(),
    );
  }

  @override
  State<OfflineProvincesModal> createState() => _OfflineProvincesModalState();
}

class _OfflineProvincesModalState extends State<OfflineProvincesModal> {
  late final ProvinceManagerService _manager;
  late final LocalStorageService _localStorage;

  List<Map<String, dynamic>> _downloadedProvinces = [];
  int _totalCachedTowers = 0;
  bool _isLoading = true;

  // Active download state
  String? _downloadingCode;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';

  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? ServiceLocator.provinceManagerService;
    _localStorage = widget.localStorage ?? ServiceLocator.localStorageService;
    _loadState();
  }

  Future<void> _loadState() async {
    final downloaded = await _localStorage.getDownloadedProvinces();
    final total = await _localStorage.getTotalCachedTowersCount();
    if (mounted) {
      setState(() {
        _downloadedProvinces = downloaded;
        _totalCachedTowers = total;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadProvince(ProvinceData province) async {
    if (_downloadingCode != null) return;

    setState(() {
      _downloadingCode = province.code;
      _downloadProgress = 0.0;
      _downloadStatusText = 'Iniciando...';
    });

    try {
      await _manager.downloadProvince(
        province: province,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _downloadStatusText = status;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar ${province.name}: $e'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingCode = null;
        });
        await _loadState();
      }
    }
  }

  Future<void> _deleteProvince(ProvinceData province) async {
    await _manager.deleteProvince(province);
    await _loadState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Caché de ${province.name} eliminada.'),
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.outline)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_for_offline, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descarga de Provincias (Offline)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Total en SQLite: $_totalCachedTowers antenas listas sin cobertura',
                        style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Active Download Progress Banner
          if (_downloadingCode != null)
            Container(
              padding: const EdgeInsets.all(14),
              color: AppColors.surfaceVariant,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _downloadStatusText,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: AppColors.outline,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

          // Province List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: ProvinceManagerService.provinces.length,
                    separatorBuilder: (_, _) => const Divider(color: AppColors.outline, height: 1),
                    itemBuilder: (context, index) {
                      final province = ProvinceManagerService.provinces[index];
                      final cachedMeta = _downloadedProvinces.firstWhere(
                        (p) => p['code'] == province.code,
                        orElse: () => {},
                      );
                      final bool isDownloaded = cachedMeta.isNotEmpty;
                      final int count = isDownloaded ? (cachedMeta['towerCount'] as int? ?? 0) : 0;
                      final bool isThisDownloading = _downloadingCode == province.code;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        title: Row(
                          children: [
                            Text(
                              province.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            if (isDownloaded)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.alignedGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.alignedGreen, width: 1),
                                ),
                                child: Text(
                                  '$count antenas',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.alignedGreen,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          isDownloaded
                              ? 'Disponible 100% offline sin conexión'
                              : 'Toca descargar para guardar en SQLite',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDownloaded ? AppColors.onSurfaceVariant : AppColors.outline,
                          ),
                        ),
                        trailing: isThisDownloading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDownloaded)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.accentError),
                                      tooltip: 'Borrar caché',
                                      onPressed: () => _deleteProvince(province),
                                    ),
                                  FilledButton.tonalIcon(
                                    onPressed: _downloadingCode != null
                                        ? null
                                        : () => _downloadProvince(province),
                                    icon: Icon(
                                      isDownloaded ? Icons.refresh : Icons.download,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isDownloaded ? 'Actualizar' : 'Descargar',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
