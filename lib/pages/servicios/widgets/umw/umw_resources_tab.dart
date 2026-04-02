import 'package:flutter/material.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/models/servicio_staff_model.dart';
import 'package:infoapp/pages/servicios/models/servicio_repuesto_model.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/pages/servicios/workflow/estado_workflow_models.dart';
import 'package:infoapp/pages/servicios/models/operacion_model.dart'; // ✅ NUEVO

class UmwResourcesTab extends StatelessWidget {
  final ServicioModel servicio;
  final List<ServicioStaffModel> staffAsignado;
  final List<ServicioRepuestoModel> repuestosAsignados;
  final List<OperacionModel> operaciones; // ✅ NUEVO
  final bool isLoadingStaff;
  final bool isLoadingRepuestos;
  final bool estaBloqueado;
  final List<WorkflowTransicionDef> accionesDisponibles;

  // Callbacks
  final Function(int? opId) onGestionarStaff;
  final Function(int? opId) onGestionarRepuestos;
  final Function(ServicioRepuestoModel) onEliminarRepuesto;
  final Function(bool?) onSuministraronRepuestosChanged;
  final VoidCallback? onConfirmarRepuestos; // ✅ NUEVO
  final VoidCallback? onConfirmarFotos; // ✅ NUEVO
  final VoidCallback? onConfirmarFirma; // ✅ NUEVO

  const UmwResourcesTab({
    super.key,
    required this.servicio,
    required this.staffAsignado,
    required this.repuestosAsignados,
    required this.operaciones, // ✅ NUEVO
    this.isLoadingStaff = false,
    this.isLoadingRepuestos = false,
    this.estaBloqueado = false,
    required this.onGestionarStaff,
    required this.onGestionarRepuestos,
    required this.onEliminarRepuesto,
    required this.onSuministraronRepuestosChanged,
    required this.accionesDisponibles,
    this.onConfirmarRepuestos,
    this.onConfirmarFotos,
    this.onConfirmarFirma,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingStaff || isLoadingRepuestos) {
      return const Center(child: CircularProgressIndicator());
    }

    // 1. Identificar Operación Maestra
    final masterOp = operaciones.firstWhere(
      (o) => o.isMaster,
      orElse:
          () => OperacionModel(
            id: -1,
            servicioId: servicio.id ?? 0,
            descripcion: 'Alistamiento/General (Maestra)',
            isMaster: true,
          ),
    );

    // 2. Agrupar Recursos por Operación
    // Aquellos con operacion_id null o que no existan en la lista de operaciones van a la maestra
    final availableOpIds = operaciones.map((o) => o.id).toSet();

    final staffMap = <int?, List<ServicioStaffModel>>{};
    for (var s in staffAsignado) {
      final opId =
          (s.operacionId == null || !availableOpIds.contains(s.operacionId))
              ? masterOp.id
              : s.operacionId;
      staffMap.putIfAbsent(opId, () => []).add(s);
    }

    final repuestosMap = <int?, List<ServicioRepuestoModel>>{};
    for (var r in repuestosAsignados) {
      final opId =
          (r.operacionId == null || !availableOpIds.contains(r.operacionId))
              ? masterOp.id
              : r.operacionId;
      repuestosMap.putIfAbsent(opId, () => []).add(r);
    }

    // 3. Ordenar operaciones (Maestra primero, luego por id/fecha)
    final sortedOps = List<OperacionModel>.from(operaciones);
    if (!sortedOps.any((o) => o.id == masterOp.id) && masterOp.id != -1) {
      // Si por alguna razón la maestra no está en la lista pero tiene ID, no debería pasar
    }

    // Asegurar que la maestra esté al principio si no está
    if (!sortedOps.any((o) => o.isMaster)) {
      // La lógica del backend garantiza que existe, pero por si acaso en UI:
    }
    sortedOps.sort((a, b) {
      if (a.isMaster) return -1;
      if (b.isMaster) return 1;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Informativo (Opcional si solo hay maestra)
          if (operaciones.length <= 1) _buildUnifiedModeBanner(context),

          const SizedBox(height: 12),

          // Renderizar cada Operación con sus recursos
          ...sortedOps.map(
            (op) => _buildOperationBlock(
              context,
              op,
              staffMap[op.id] ?? [],
              repuestosMap[op.id] ?? [],
            ),
          ),

          const SizedBox(height: 24),
          if (accionesDisponibles.any(
            (a) =>
                a.triggerCode == 'FOTO_SUBIDA' ||
                a.triggerCode == 'FIRMA_CLIENTE',
          ))
            _buildEvidenciasConfirmacion(context),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildUnifiedModeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.info(), color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Modo Unificado: Todos los recursos están agrupados en el Alistamiento General por defecto.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationBlock(
    BuildContext context,
    OperacionModel op,
    List<ServicioStaffModel> staff,
    List<ServicioRepuestoModel> repuestos,
  ) {
    final theme = Theme.of(context);
    final isMaster = op.isMaster;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la Operación
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isMaster
                      ? theme.primaryColor.withOpacity(0.05)
                      : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMaster
                      ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                      : PhosphorIcons.target(),
                  color: isMaster ? Colors.orange : theme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        op.descripcion,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isMaster ? Colors.black87 : theme.primaryColor,
                        ),
                      ),
                      if (isMaster)
                        const Text(
                          'OPERACIÓN MAESTRA',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                // Botones rápido de gestión para esta operación
                if (!estaBloqueado)
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.userPlus(),
                          size: 18,
                          color: Colors.orange,
                        ),
                        onPressed: () => onGestionarStaff(op.id), // ✅ PASAR ID
                        tooltip: 'Agregar Personal',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.package(),
                          size: 18,
                          color: Colors.blue,
                        ),
                        onPressed:
                            () => onGestionarRepuestos(op.id), // ✅ PASAR ID
                        tooltip: 'Agregar Repuestos',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Contenido: Personal
          if (staff.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _buildMiniHeader(
                'Personal (${staff.length})',
                PhosphorIcons.users(),
                Colors.orange,
              ),
            ),
            _buildStaffList(context, staff),
          ],

          // Contenido: Repuestos
          if (repuestos.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildMiniHeader(
                'Repuestos (${repuestos.length})',
                PhosphorIcons.package(),
                Colors.blue,
              ),
            ),
            _buildRepuestosGrid(context, repuestos),
          ],

          if (staff.isEmpty && repuestos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Sin recursos asignados a esta operación',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMiniHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStaffList(BuildContext context, List<ServicioStaffModel> staff) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staff.length,
      itemBuilder: (context, index) {
        final s = staff[index];
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.orange.withOpacity(0.1),
            child: Text(
              s.firstName.isNotEmpty ? s.firstName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            '${s.firstName} ${s.lastName}',
            style: const TextStyle(fontSize: 12),
          ),
          subtitle:
              s.positionTitle != null
                  ? Text(s.positionTitle!, style: const TextStyle(fontSize: 9))
                  : null,
        );
      },
    );
  }

  Widget _buildRepuestosGrid(
    BuildContext context,
    List<ServicioRepuestoModel> repuestos,
  ) {
    if (repuestos.isEmpty) {
      return _buildEmptyState('Sin repuestos', PhosphorIcons.package());
    }

    double totalOp = repuestos.fold(0, (sum, r) => sum + r.costoTotal);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Encabezado de Tabla
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('ITEM / SKU', style: _tableHeaderStyle),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'CANT',
                  textAlign: TextAlign.center,
                  style: _tableHeaderStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'TOTAL',
                  textAlign: TextAlign.right,
                  style: _tableHeaderStyle,
                ),
              ),
              if (!estaBloqueado)
                const SizedBox(width: 40), // Espacio para eliminar
            ],
          ),
        ),

        // Filas de Repuestos
        ...repuestos.map(
          (r) => Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.itemNombre ?? 'Item',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (r.itemSku != null)
                        Text(
                          r.itemSku!,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'x${r.cantidad.toStringAsFixed(1)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '\$${r.costoTotal.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!estaBloqueado)
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => onEliminarRepuesto(r),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Subtotal de la Operación
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Subtotal Operación: ',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                '\$${totalOp.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _tableHeaderStyle = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.bold,
    color: Colors.grey,
    letterSpacing: 0.5,
  );

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.primaryColor, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
      ],
    );
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
    final confirmedRepuestos = servicio.suministraronRepuestos ?? false;

    // ✅ SOLO mostrar "Confirmar Repuestos" en esta pestaña (Recursos)
    // Los disparadores de fotos y firma se delegan a sus pestañas respectivas
    final requiereRepuestos = accionesDisponibles.any(
      (a) => a.triggerCode == 'OS_REPUESTOS',
    );

    if (!requiereRepuestos) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          context,
          'Confirmación de Recursos',
          PhosphorIcons.checkCircle(),
        ),
        const SizedBox(height: 16),

        // Confirmar Repuestos
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  confirmedRepuestos || onConfirmarRepuestos == null
                      ? null
                      : onConfirmarRepuestos,
              icon: Icon(
                confirmedRepuestos
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.package(),
                size: 20,
              ),
              label: Text(
                confirmedRepuestos
                    ? 'Repuestos Confirmados ✓'
                    : 'Confirmar Entrega de Repuestos',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    confirmedRepuestos
                        ? Colors.green.withOpacity(0.1)
                        : theme.primaryColor.withOpacity(0.1),
                foregroundColor:
                    confirmedRepuestos
                        ? Colors.green.shade700
                        : theme.primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      String dateStr = isoDate;
      if (!dateStr.contains('Z') && !dateStr.contains('+')) {
        dateStr = dateStr.replaceFirst(' ', 'T');
        if (!dateStr.endsWith('Z')) dateStr += 'Z';
      }
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
