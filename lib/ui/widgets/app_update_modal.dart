import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/update_service.dart';

/// Modal dialog providing the technician with Over-The-Air app update tools.
class AppUpdateModal extends StatefulWidget {
  final UpdateService? updateService;

  const AppUpdateModal({super.key, this.updateService});

  static Future<void> show(BuildContext context, {UpdateService? updateService}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AppUpdateModal(updateService: updateService),
    );
  }

  @override
  State<AppUpdateModal> createState() => _AppUpdateModalState();
}

class _AppUpdateModalState extends State<AppUpdateModal> {
  late final UpdateService _service;
  bool _canInstallPackages = true;

  @override
  void initState() {
    super.initState();
    _service = widget.updateService ?? UpdateService();
    _service.addListener(_onServiceUpdate);
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    final allowed = await _service.canRequestPackageInstalls();
    if (mounted) {
      setState(() => _canInstallPackages = allowed);
    }
    // Check update on launch if idle
    if (_service.state == UpdateState.idle) {
      _service.checkForUpdate(mockUpdate: true);
    }
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final update = _service.availableUpdate;
    final isDownloading = _service.state == UpdateState.downloading;
    final isReady = _service.state == UpdateState.readyToInstall;
    final isChecking = _service.state == UpdateState.checking;
    final isUpdateAvailable = _service.state == UpdateState.updateAvailable || isDownloading || isReady;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actualizaciones del Terminal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Versión instalada: v${_service.currentVersion} (Build ${_service.currentBuildNumber})',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!isDownloading && !isChecking)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.onSurfaceVariant),
                    tooltip: 'Comprobar ahora',
                    onPressed: () => _service.checkForUpdate(mockUpdate: true),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.outline),
            const SizedBox(height: 12),

            // State feedback banner
            if (isChecking) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    SizedBox(width: 12),
                    Text('Buscando nuevas versiones...', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_service.state == UpdateState.upToDate) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentSuccess.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentSuccess.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.accentSuccess, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Terminal al día', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentSuccess, fontSize: 13)),
                          Text('Tienes instalada la versión más reciente (v${_service.currentVersion}).',
                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (isUpdateAvailable && update != null) ...[
              // Update available card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NUEVA: v${update.version}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        if (update.fileSizeBytes != null)
                          Text(
                            '${(update.fileSizeBytes! / 1048576).toStringAsFixed(1)} MB',
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Novedades y mejoras:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        update.releaseNotes,
                        style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Install Permission Warning if Android blocks unknown sources
              if (!_canInstallPackages) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentWarning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentWarning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_update_warning, color: AppColors.accentWarning, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Se requiere autorizar la instalación de aplicaciones desde esta fuente.',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _service.openInstallPermissionSettings();
                          // Recheck after returning
                          final allowed = await _service.canRequestPackageInstalls();
                          if (mounted) setState(() => _canInstallPackages = allowed);
                        },
                        child: const Text('Autorizar', style: TextStyle(color: AppColors.accentWarning, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Downloading Progress Indicator
              if (isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _service.downloadProgress > 0 ? _service.downloadProgress : null,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _service.statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Action Button (Thumb zone compliant, minimum 48px height)
            if (isReady)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.install_mobile, color: Colors.white),
                  label: const Text('Instalar Actualización Ahora', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSuccess,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final ok = await _service.installApk();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_service.statusMessage.isNotEmpty ? _service.statusMessage : 'Error al lanzar instalador'),
                          backgroundColor: AppColors.accentError,
                        ),
                      );
                    }
                  },
                ),
              )
            else if (isUpdateAvailable && !isDownloading)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  label: Text('Descargar e Instalar v${update?.version}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (!_canInstallPackages) {
                      await _service.openInstallPermissionSettings();
                      final allowed = await _service.canRequestPackageInstalls();
                      if (mounted) setState(() => _canInstallPackages = allowed);
                    }
                    if (update != null) {
                      final file = await _service.downloadApk(update);
                      if (file != null && mounted) {
                        await _service.installApk();
                      }
                    }
                  },
                ),
              )
            else if (!isChecking)
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check, color: AppColors.primary),
                  label: const Text('Comprobar de nuevo', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _service.checkForUpdate(mockUpdate: true),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
