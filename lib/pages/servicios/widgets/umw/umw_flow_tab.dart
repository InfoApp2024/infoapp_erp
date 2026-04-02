import 'package:flutter/material.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/workflow/estado_workflow_models.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/pages/servicios/forms/widgets/fotos_servicio_widget.dart';

class UmwFlowTab extends StatelessWidget {
  final ServicioModel servicio;
  final List<WorkflowTransicionDef> accionesDisponibles;
  final Function(WorkflowTransicionDef, BuildContext) onAccionPressed;
  final bool isAnulling;
  final bool estaBloqueado;
  final VoidCallback? onConfirmarFotos;
  final VoidCallback? onConfirmarFirma;
  final Function(String)? onRegistrarAuditoria; // ✅ NUEVO

  const UmwFlowTab({
    super.key,
    required this.servicio,
    required this.accionesDisponibles,
    required this.onAccionPressed,
    this.isAnulling = false,
    this.estaBloqueado = false,
    this.onConfirmarFotos,
    this.onConfirmarFirma,
    this.onRegistrarAuditoria, // ✅ NUEVO
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda: Fotos (Evidencias)
                Expanded(
                  flex: 3,
                  child: FotosServicioWidget(
                    servicioId: servicio.id!,
                    numeroServicio:
                        servicio.oServicio?.toString() ?? servicio.id.toString(),
                    enabled: !isAnulling && !estaBloqueado,
                  ),
                ),

                const SizedBox(width: 24),

                // Columna Derecha: Confirmaciones y Auditoría
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildEvidenciasConfirmacion(context),
                      const SizedBox(height: 16),
                      _buildAuditoriaPanel(context),

                      if (accionesDisponibles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Text(
                            'Utilice los botones en la barra superior para cambiar el estado.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Layout Móvil (Columnar)
        return SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección de Fotos (Evidencias)
              FotosServicioWidget(
                servicioId: servicio.id!,
                numeroServicio:
                    servicio.oServicio?.toString() ?? servicio.id.toString(),
                enabled: !isAnulling && !estaBloqueado,
              ),

              const SizedBox(height: 20),
              _buildEvidenciasConfirmacion(context),
              const SizedBox(height: 20),
              _buildAuditoriaPanel(context), // ✅ NUEVO: Panel de Auditoría SoD

              if (accionesDisponibles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text(
                      'Utilice los botones en la barra superior para cambiar el estado.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context, WorkflowTransicionDef accion) {
    final theme = Theme.of(context);
    Color btnColor;

    // Asignar colores según la semántica de la acción
    final nombreAccion = accion.nombre?.toLowerCase() ?? '';

    if (nombreAccion.contains('anular') || nombreAccion.contains('cancelar')) {
      btnColor = Colors.red.shade700;
    } else if (nombreAccion.contains('finalizar') ||
        nombreAccion.contains('aprobar')) {
      btnColor = Colors.green.shade700;
    } else {
      btnColor = theme.primaryColor;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: btnColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: () => onAccionPressed(accion, context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: btnColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForAndTrigger(accion.triggerCode),
                  color: btnColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accion.nombre ?? 'Acción',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: btnColor,
                      ),
                    ),
                    /* if (accion.requiereFirma == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.penNib(), size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            const Text(
                              'Requiere Firma',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ), */
                  ],
                ),
              ),
              Icon(PhosphorIcons.caretRight(), color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForAndTrigger(String? trigger) {
    if (trigger == null) return PhosphorIcons.arrowRight();
    if (trigger.contains('FIRMA')) return PhosphorIcons.penNib();
    if (trigger.contains('FOTO')) return PhosphorIcons.camera();
    if (trigger.contains('QR')) return PhosphorIcons.qrCode();
    return PhosphorIcons.arrowRight();
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenciasConfirmacion(BuildContext context) {
    final theme = Theme.of(context);
    final confirmedFotos = servicio.fotosConfirmadas ?? false;

    // ✅ SOLO mostrar si alguna acción disponible requiere el trigger de fotos
    final requiereFotos = accionesDisponibles.any(
      (a) => a.triggerCode == 'FOTO_SUBIDA',
    );

    if (!requiereFotos) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Confirmar Fotos
        if (requiereFotos)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    confirmedFotos || estaBloqueado || onConfirmarFotos == null
                        ? null
                        : onConfirmarFotos,
                icon: Icon(
                  confirmedFotos
                      ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                      : PhosphorIcons.camera(),
                  size: 20,
                ),
                label: Text(
                  confirmedFotos
                      ? 'Fotos Confirmadas ✓'
                      : 'Confirmar Fotos de Evidencia',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      confirmedFotos ? Colors.green : theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

        // El botón de confirmar firma se ha removido ya que la confirmación
        // ahora es automática al momento de guardar la firma en el backend.
      ],
    );
  }

  // ✅ NUEVO: Panel de Auditoría Financiera (SoD)
  Widget _buildAuditoriaPanel(BuildContext context) {
    // print('DEBUG: UmwFlowTab.auditoriaInfo: ${servicio.auditoriaInfo}');
    if (servicio.auditoriaInfo == null) return const SizedBox.shrink();

    final audit = servicio.auditoriaInfo!;
    final theme = Theme.of(context);
    final isAuditado = audit.auditado;
    final tieneHistorial = audit.historial.isNotEmpty;
    final esApto = audit.esAptoParaLegalizado;
    final sePuedeAuditar = onRegistrarAuditoria != null && esApto && !isAuditado;

    // print('DEBUG: isAuditado=$isAuditado, tieneHistorial=$tieneHistorial, sePuedeAuditar=$sePuedeAuditar');

    final showHeader = isAuditado || sePuedeAuditar;
    final showHistoryOnly = !showHeader && tieneHistorial;

    if (!isAuditado && !tieneHistorial && !sePuedeAuditar) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAuditado ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      color: isAuditado ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                children: [
                  Icon(
                    isAuditado
                        ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                        : PhosphorIcons.shieldCheck(),
                    color:
                        isAuditado
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAuditado
                          ? 'SERVICIO AUDITADO'
                          : 'REQUIERE AUDITORÍA FINANCIERA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color:
                            isAuditado
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                      ),
                    ),
                  ),
                  if (isAuditado)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'APROBADO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isAuditado) ...[
                Text(
                  'Auditado por: ${audit.auditorNombre ?? '---'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (audit.fechaAuditoria != null)
                  Text(
                    'Fecha: ${audit.fechaAuditoria!.day}/${audit.fechaAuditoria!.month}/${audit.fechaAuditoria!.year}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                if (audit.comentario != null && audit.comentario!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Obs: ${audit.comentario}',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
              ] else ...[
                const Text(
                  'Este servicio requiere ser validado por un auditor autorizado antes de proceder con el cambio de estado a LEGALIZADO.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (onRegistrarAuditoria != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _mostrarDialogoAuditoria(context),
                      icon: const Icon(Icons.fact_check),
                      label: const Text('APROBAR AUDITORÍA (SOD)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ],

            if (showHistoryOnly) ...[
              Row(
                children: [
                  Icon(Icons.history, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'HISTORIAL DE AUDITORÍAS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'A continuación se muestra el registro histórico de las revisiones de este servicio.',
                style: TextStyle(fontSize: 11),
              ),
            ],

            // ✅ NUEVO: Historial de Auditorías (Trazabilidad)
            if (audit.historial.isNotEmpty) ...[
              const Divider(height: 32),
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'HISTORIAL DE REVISIONES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...audit.historial.map((item) {
                final esActual = item.id == audit.auditorId; // Simple check if it's the current one
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Rev. Ciclo ${item.ciclo}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: esActual ? Colors.green : Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${item.fecha.day}/${item.fecha.month}/${item.fecha.year}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.auditorNombre,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        item.comentario,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoAuditoria(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Aprobar Auditoría'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Al aprobar este servicio, usted confirma que ha revisado los recursos y montos asignados.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Comentario de Aprobación',
                      hintText: 'Ej: Se validan montos y recursos...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El comentario es obligatorio para aprobar.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    onRegistrarAuditoria?.call(controller.text);
                  }
                },
                child: const Text('APROBAR Y FIRMAR'),
              ),
            ],
          ),
    );
  }
}
