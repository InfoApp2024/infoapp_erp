import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/servicio_model.dart';
import '../../models/servicio_staff_model.dart';
import '../../models/servicio_repuesto_model.dart';
import '../../../firmas/models/firma_model.dart';
import '../../models/service_time_log_model.dart';
import 'package:infoapp/pages/servicios/models/operacion_model.dart';

/// Widget que muestra un resumen consolidado de toda la actividad del servicio.
/// Incluye operaciones, personal, repuestos, firmas y tiempos.
class UmwServiceSummary extends StatelessWidget {
  final ServicioModel servicio;
  final List<OperacionModel> operaciones;
  final List<ServicioStaffModel> staff;
  final List<ServicioRepuestoModel> repuestos;
  final FirmaModel? firma;
  final List<ServiceTimeLogModel> logsTiempo;

  const UmwServiceSummary({
    super.key,
    required this.servicio,
    required this.operaciones,
    required this.staff,
    required this.repuestos,
    this.firma,
    this.logsTiempo = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(PhosphorIcons.listChecks(), color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'RESUMEN EJECUTIVO DEL SERVICIO',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),

        // Tarjetas de Resumen
        _buildSectionCard(
          context,
          title: 'Operaciones Ejecutadas',
          icon: PhosphorIcons.wrench(),
          content: _buildOperationsList(theme),
          emptyMessage: 'No hay operaciones registradas aún.',
          isEmpty: operaciones.isEmpty,
        ),

        _buildSectionCard(
          context,
          title: 'Recursos Asignados',
          icon: PhosphorIcons.usersFour(),
          content: _buildResourcesGrid(theme),
          emptyMessage: 'No hay personal ni repuestos asignados.',
          isEmpty: staff.isEmpty && repuestos.isEmpty,
        ),

        if (firma != null || servicio.isFirmaConfirmada)
          _buildSectionCard(
            context,
            title: 'Detalles de Entrega y Firma',
            icon: PhosphorIcons.signature(),
            content: _buildSignatureDetails(theme),
            emptyMessage: 'Esperando registro de firmas.',
            isEmpty: firma == null,
          ),

        _buildSectionCard(
          context,
          title: 'Tiempos del Servicio',
          icon: PhosphorIcons.clockClockwise(),
          content: _buildTimeDetails(theme),
          emptyMessage: 'No hay registros de tiempo disponibles.',
          isEmpty: logsTiempo.isEmpty && servicio.fechaIngreso == null,
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget content,
    required String emptyMessage,
    required bool isEmpty,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la tarjeta
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Contenido
          Padding(
            padding: const EdgeInsets.all(12),
            child: isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        emptyMessage,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                : content,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsList(ThemeData theme) {
    final List<Widget> children = [];
    
    // Tomar solo las primeras 5 operaciones
    final firstOps = operaciones.take(5).toList();
    for (var op in firstOps) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(PhosphorIcons.caretCircleRight(), size: 14, color: theme.primaryColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  op.descripcion,
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (operaciones.length > 5) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 22),
          child: Text(
            '+ ${operaciones.length - 5} operaciones adicionales...',
            style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildResourcesGrid(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (staff.isNotEmpty) ...[
          const Text('PERSONAL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: staff.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.user(), size: 12, color: theme.primaryColor),
                  const SizedBox(width: 6),
                  Text(s.fullName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.primaryColor)),
                ],
              ),
            )).toList(),
          ),
          if (repuestos.isNotEmpty) const SizedBox(height: 16),
        ],
        
        if (repuestos.isNotEmpty) ...[
          const Text('REPUESTOS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          ..._buildRepuestosList(theme),
        ],
      ],
    );
  }

  List<Widget> _buildRepuestosList(ThemeData theme) {
    final List<Widget> items = [];
    final limitedRepuestos = repuestos.take(3).toList();
    
    for (var r in limitedRepuestos) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(PhosphorIcons.package(), size: 14, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${r.cantidad.toStringAsFixed(0)}x ${r.itemNombre}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (repuestos.length > 3) {
      items.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, left: 22),
            child: Text(
              '+ ${repuestos.length - 3} repuestos más...',
              style: TextStyle(color: Colors.blueGrey[600], fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );
    }
    
    return items;
  }

  Widget _buildSignatureDetails(ThemeData theme) {
    if (firma == null) {
      return Row(
        children: [
          Icon(PhosphorIcons.info(), size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Firmas confirmadas en sistema, pero detalles no cargados.',
              style: TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildInfoRow(
          theme,
          label: 'ENTREGADO POR',
          value: firma!.staffNombre ?? 'No especificado',
          icon: PhosphorIcons.userCircle(),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          theme,
          label: 'RECIBIDO POR',
          value: firma!.funcionarioNombre ?? 'No especificado',
          icon: PhosphorIcons.identificationCard(),
        ),
        if (firma!.notaRecepcion != null && firma!.notaRecepcion!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.chatText(), size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    firma!.notaRecepcion!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeDetails(ThemeData theme) {
    final String fechaIngreso = servicio.fechaIngreso ?? 'N/A';
    final String fechaFin = servicio.fechaFinalizacion ?? 'Pendiente';
    
    // Buscar log de finalización para duración real si existe
    String duracionTotal = 'N/A';
    if (logsTiempo.isNotEmpty) {
      // Sumar todas las duraciones
      int totalSecs = logsTiempo.fold(0, (sum, log) => sum + log.durationSeconds);
      if (totalSecs > 0) {
        final duration = Duration(seconds: totalSecs);
        duracionTotal = _formatDuration(duration);
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTimeItem(theme, 'INGRESO', fechaIngreso, PhosphorIcons.calendarPlus())),
            Container(width: 1, height: 30, color: Colors.grey[200], margin: const EdgeInsets.symmetric(horizontal: 8)),
            Expanded(child: _buildTimeItem(theme, 'FINALIZACIÓN', fechaFin, PhosphorIcons.calendarCheck())),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TIEMPO TOTAL TRANSCURRIDO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.primaryColor)),
              Text(duracionTotal, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.primaryColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeItem(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, {required String label, required String value, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}
