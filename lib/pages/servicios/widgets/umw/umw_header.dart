import 'package:flutter/material.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/workflow/estado_workflow_models.dart';
import 'dart:ui';

class UmwHeader extends StatelessWidget {
  final ServicioModel servicio;
  final bool isWeb;
  final VoidCallback? onBackPressed;
  final List<WorkflowTransicionDef> acciones;
  final Function(WorkflowTransicionDef, BuildContext)? onAccionPressed;

  const UmwHeader({
    super.key,
    required this.servicio,
    required this.isWeb,
    this.onBackPressed,
    this.acciones = const [],
    this.onAccionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 24 : 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.90),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _buildLeading(context),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfo(theme)),
                  const SizedBox(width: 8),
                  _buildStatusBadge(theme),
                ],
              ),
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),
                _buildActionsBar(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onBackPressed ?? () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildInfo(ThemeData theme) {
    // Lógica para mostrar O. Servicio o ID
    final titulo =
        servicio.oServicio != null && servicio.oServicio! > 0
            ? 'Orden #${servicio.oServicio}'
            : 'Servicio #${servicio.id ?? '---'}';

    // Lógica para nombre de cliente (prioridad: clienteNombre > nombreEmp)
    final subtitulo =
        servicio.clienteNombre != null && servicio.clienteNombre!.isNotEmpty
            ? servicio.clienteNombre!
            : (servicio.nombreEmp ?? 'Cliente no especificado');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitulo,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final estado = servicio.estadoNombre ?? 'Pendiente';

    final statusColor = theme.primaryColor;

    // Asegurar que el color sea visible sobre el fondo del header

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            estado.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsBar(BuildContext context) {
    if (acciones.isEmpty) return const SizedBox.shrink();

    // 1. Helper function for intelligent fallback of transition names
    String getTransitionLabel(WorkflowTransicionDef accion) {
      final String rawName = accion.nombre ?? '';
      if (rawName.trim().isEmpty ||
          rawName.trim().toLowerCase() == 'transición') {
        return accion.to.toUpperCase();
      }
      return rawName.toUpperCase();
    }

    // 2. Identificar categorías de acciones
    WorkflowTransicionDef? accionAnular;
    final otrasAcciones =
        acciones.where((a) {
          final label = getTransitionLabel(a).toLowerCase();
          if (label.contains('anular') || label.contains('cancelar')) {
            accionAnular = a;
            return false;
          }
          return true;
        }).toList();

    final triggerAcciones =
        otrasAcciones
            .where((a) => a.triggerCode != null && a.triggerCode!.isNotEmpty)
            .toList();
    final manualAcciones =
        otrasAcciones
            .where((a) => a.triggerCode == null || a.triggerCode!.isEmpty)
            .toList();

    return Container(
      alignment: isWeb ? Alignment.centerRight : Alignment.centerLeft,
      child:
          isWeb
              ? Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.end,
                children: [
                  ...triggerAcciones.map(
                    (accion) => _buildCompactButton(
                      context,
                      accion,
                      isTrigger: true,
                      label: getTransitionLabel(accion),
                    ),
                  ),
                  if (accionAnular != null)
                    _buildCompactButton(
                      context,
                      accionAnular!,
                      isCritical: true,
                      label: getTransitionLabel(accionAnular!),
                    ),
                  if (manualAcciones.isNotEmpty)
                    _buildManualActionsDropdown(
                      context,
                      manualAcciones,
                      getTransitionLabel,
                    ),
                ],
              )
              : _buildMobileMenuButton(
                context,
                triggerAcciones,
                accionAnular,
                manualAcciones,
                getTransitionLabel,
              ),
    );
  }

  Widget _buildMobileMenuButton(
    BuildContext context,
    List<WorkflowTransicionDef> triggers,
    WorkflowTransicionDef? anular,
    List<WorkflowTransicionDef> manuales,
    String Function(WorkflowTransicionDef) getLabel,
  ) {
    return ElevatedButton.icon(
      onPressed:
          () =>
              _showAccionesMenu(context, triggers, anular, manuales, getLabel),
      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
      label: const Text(
        'GESTIONAR SERVICIO',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAccionesMenu(
    BuildContext context,
    List<WorkflowTransicionDef> triggers,
    WorkflowTransicionDef? anular,
    List<WorkflowTransicionDef> manuales,
    String Function(WorkflowTransicionDef) getLabel,
  ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Acciones Disponibles',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                const Divider(),

                // Triggers
                ...triggers.map(
                  (accion) => ListTile(
                    leading: Icon(
                      Icons.play_circle_outline,
                      color: theme.primaryColor,
                    ),
                    title: Text(
                      getLabel(accion),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onAccionPressed?.call(accion, context);
                    },
                  ),
                ),

                // Manuales
                ...manuales.map(
                  (accion) => ListTile(
                    leading: const Icon(Icons.sync_alt, color: Colors.blue),
                    title: Text(getLabel(accion)),
                    onTap: () {
                      Navigator.pop(context);
                      onAccionPressed?.call(accion, context);
                    },
                  ),
                ),

                // Anular
                if (anular != null)
                  ListTile(
                    leading: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.red,
                    ),
                    title: Text(
                      getLabel(anular),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onAccionPressed?.call(anular, context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualActionsDropdown(
    BuildContext context,
    List<WorkflowTransicionDef> manuales,
    String Function(WorkflowTransicionDef) getLabel,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(cardColor: Colors.white),
      child: PopupMenuButton<WorkflowTransicionDef>(
        onSelected: (accion) => onAccionPressed?.call(accion, context),
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MÁS ESTADOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
            ],
          ),
        ),
        itemBuilder:
            (context) =>
                manuales
                    .map(
                      (accion) => PopupMenuItem(
                        value: accion,
                        child: Row(
                          children: [
                            Icon(
                              Icons.sync_alt,
                              size: 18,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              getLabel(accion),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
      ),
    );
  }

  Widget _buildCompactButton(
    BuildContext context,
    WorkflowTransicionDef accion, {
    bool isTrigger = false,
    bool isCritical = false,
    String? label,
  }) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isExtraSmall = screenWidth < 340;

    // Si es trigger: fondo blanco, texto color primario
    // Si es crítico (anular): fondo rojo, texto blanco
    // Si es manual: fondo traslúcido, texto blanco
    final color =
        isCritical
            ? Colors.red.shade400
            : (isTrigger ? Colors.white : Colors.white.withOpacity(0.2));

    final textColor =
        (isTrigger && !isCritical) ? theme.primaryColor : Colors.white;

    final borderColor =
        isTrigger ? Colors.white.withOpacity(0.5) : Colors.white24;

    final String displayLabel = label ?? accion.nombre?.toUpperCase() ?? '';

    return ElevatedButton(
      onPressed: () => onAccionPressed?.call(accion, context),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: isWeb ? 2 : 0,
        padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 16 : (isExtraSmall ? 6 : 10),
          vertical: isWeb ? 0 : 8,
        ),
        minimumSize: isWeb ? const Size(64, 36) : Size.zero,
        tapTargetSize:
            isWeb
                ? MaterialTapTargetSize.padded
                : MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
        visualDensity: isWeb ? VisualDensity.standard : VisualDensity.compact,
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isWeb ? 11 : (isExtraSmall ? 8.5 : 9.5),
          letterSpacing: isWeb ? 0.5 : 0.2,
          color: textColor,
        ),
      ),
    );
  }

}
