import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telecli_afr/core/theme/app_colors.dart';
import 'package:telecli_afr/core/utils/geo_calculator.dart';
import 'package:telecli_afr/data/models/installation_job.dart';
import '../view_models/saved_jobs_view_model.dart';

/// Screen listing saved antenna installation reports and export tools.
/// Conforms to MVVM architecture consuming SavedJobsViewModel.
class SavedJobsScreen extends StatefulWidget {
  final SavedJobsViewModel? viewModel;

  const SavedJobsScreen({super.key, this.viewModel});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  late final SavedJobsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? SavedJobsViewModel();
    _viewModel.loadJobs();
  }

  String _generateReportText(InstallationJob job) {
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(job.createdAt);
    return '''
📋 BOLETÍN OFICIAL DE MEDIDA E INSTALACIÓN MOVISTAR AFR 5G
------------------------------------------------------------
EXPEDIENTE Y CLIENTE:
Cliente: ${job.clientName}
Dirección: ${job.clientAddress}
Coordenadas GPS: ${job.clientLat.toStringAsFixed(6)}, ${job.clientLon.toStringAsFixed(6)}
Precisión GPS: ${job.gpsAccuracyMeters != null ? '±${job.gpsAccuracyMeters!.toStringAsFixed(1)} m' : 'Alta (GNSS Fix)'}
Fecha y Hora de Medida: $formattedDate

DATOS DE LA ESTACIÓN BASE Y ENLACE:
Código Emplazamiento Minetur: ${job.towerCode}
Dirección Estación Base: ${job.towerAddress}
Tecnología / Banda 5G: ${job.technologyBand}
Distancia a la Estación: ${GeoCalculator.formatDistance(job.distanceMeters)}

PARÁMETROS DE ORIENTACIÓN Y APUNTAMIENTO:
Rumbo / Azimut FWA: ${job.targetBearing.toStringAsFixed(1)}° (${GeoCalculator.bearingToCardinal(job.targetBearing)})
Inclinación Mecánica (Tilt): ${job.mechanicalTiltDeg != null ? '${job.mechanicalTiltDeg!.toStringAsFixed(1)}°' : '0.0°'}
Declinación Magnética: ${job.magneticDeclinationDeg != null ? '${job.magneticDeclinationDeg! >= 0 ? '+' : ''}${job.magneticDeclinationDeg!.toStringAsFixed(1)}°' : '-0.5°'}

TELEMETRÍA RF Y PROPAGACIÓN:
Pérdida Espacio Libre (FSPL): ${job.fsplDb != null ? '${job.fsplDb!.toStringAsFixed(1)} dB' : 'N/D'}
Radio 1ª Zona Fresnel (r₁): ${job.fresnelRadiusMeters != null ? '${job.fresnelRadiusMeters!.toStringAsFixed(2)} m' : 'N/D'}
Nivel RSRP Estimado: ${job.estimatedRsrpDbm != null ? '${job.estimatedRsrpDbm!.toStringAsFixed(1)} dBm' : 'N/D'}
Nivel RSRP Medido en Campo: ${job.rsrpDbm != null ? '${job.rsrpDbm} dBm' : 'Conforme'}
Velocidad Downlink Estimada: ${job.downlinkEstimatedMbps != null ? '${job.downlinkEstimatedMbps} Mbps' : 'Alta'}
Resultado de Instalación: ${job.status}

OBSERVACIONES DEL INSTALADOR:
${job.notes.isNotEmpty ? job.notes : 'Instalación conforme a normativa técnica Movistar AFR 5G. Mástil y fijaciones aseguradas.'}
------------------------------------------------------------
Generado por Terminal Técnico Movistar AFR 5G
''';
  }

  void _copyReportToClipboard(InstallationJob job) {
    final report = _generateReportText(job);
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Informe copiado al portapapeles! Listo para pegar.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _shareViaWhatsApp(InstallationJob job) async {
    final report = _generateReportText(job);
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(report)}');
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await SharePlus.instance.share(ShareParams(text: report, subject: 'Boletín AFR 5G - ${job.clientName}'));
      }
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: report, subject: 'Boletín AFR 5G - ${job.clientName}'));
    }
  }

  Future<void> _shareViaEmail(InstallationJob job) async {
    final report = _generateReportText(job);
    final subject = '[BOLETÍN AFR 5G] ${job.clientName} - ${job.towerCode}';
    final emailUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': subject,
        'body': report,
      },
    );
    try {
      if (!await launchUrl(emailUri, mode: LaunchMode.externalApplication)) {
        await SharePlus.instance.share(ShareParams(text: report, subject: subject));
      }
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: report, subject: subject));
    }
  }

  void _showShareOptionsModal(InstallationJob job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Compartir Boletín Técnico',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${job.clientName} • ${job.towerCode}',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.outline),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 22),
                ),
                title: const Text('Enviar por WhatsApp', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Grupo de cuadrilla o supervisor de obra', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareViaWhatsApp(job);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.email_outlined, color: AppColors.primary, size: 22),
                ),
                title: const Text('Enviar por Email', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Boletín formal con asunto y telemetría completa', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareViaEmail(job);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent5G.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.share_outlined, color: AppColors.accent5G, size: 22),
                ),
                title: const Text('Compartir en otras aplicaciones', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Telegram, Drive, Bluetooth, etc.', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(ShareParams(text: _generateReportText(job), subject: '[BOLETÍN AFR 5G] ${job.clientName}'));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 22),
                ),
                title: const Text('Copiar al portapapeles', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyReportToClipboard(job);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteJob(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar informe'),
        content: const Text('¿Deseas eliminar este registro de instalación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentError),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _viewModel.deleteJob(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final jobs = _viewModel.jobs;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Historial de Instalaciones'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _viewModel.loadJobs(),
              ),
            ],
          ),
          body: _viewModel.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : jobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 56, color: AppColors.outline.withValues(alpha: 0.6)),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay instalaciones guardadas',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Orienta una antena y pulsa "GUARDAR OBRA"\npara generar tu primer parte.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isWide = constraints.maxWidth >= 720.0;

                        Widget buildJobCard(InstallationJob job) {
                          final dateStr = DateFormat('dd/MM/yyyy • HH:mm').format(job.createdAt);

                          return RepaintBoundary(
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            job.clientName,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.alignedGreen.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            job.status,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.alignedGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      job.clientAddress,
                                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(color: AppColors.outline),
                                    const SizedBox(height: 8),

                                    // Alignment specifics
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('RUMBO FIJADO', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                                              Text(
                                                '${job.targetBearing.toStringAsFixed(0)}° (${GeoCalculator.bearingToCardinal(job.targetBearing)})',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('DISTANCIA', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                                              Text(
                                                GeoCalculator.formatDistance(job.distanceMeters),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (job.rsrpDbm != null) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('SEÑAL RSRP', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                                                Text(
                                                  '${job.rsrpDbm} dBm',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accent5G),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (job.fsplDb != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          alignment: WrapAlignment.spaceBetween,
                                          children: [
                                            Text('FSPL: ${job.fsplDb!.toStringAsFixed(1)} dB', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                                            if (job.fresnelRadiusMeters != null)
                                              Text('Fresnel: ${job.fresnelRadiusMeters!.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                                            if (job.downlinkEstimatedMbps != null)
                                              Text('DL: ${job.downlinkEstimatedMbps} Mbps', style: const TextStyle(fontSize: 11, color: AppColors.accent5G, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (job.notes.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          job.notes,
                                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.share, size: 20, color: AppColors.primary),
                                              tooltip: 'Compartir Boletín Oficial',
                                              onPressed: () => _showShareOptionsModal(job),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.accentError),
                                              tooltip: 'Eliminar informe',
                                              onPressed: () => _deleteJob(job.id),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: isWide
                                ? GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 540,
                                    mainAxisExtent: 280,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: jobs.length,
                                  itemBuilder: (context, index) => buildJobCard(jobs[index]),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: jobs.length,
                                  itemBuilder: (context, index) => buildJobCard(jobs[index]),
                                ),
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }
}
