import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';

/// Card para mostrar una transición entre estados
class TransitionCard extends StatefulWidget {
  final String id;
  final String originStateName;
  final String destinationStateName;
  final String originColor;
  final String destinationColor;
  final String triggerCode;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool canDelete;
  final bool canEdit;

  final String? modulo;

  const TransitionCard({
    super.key,
    required this.id,
    required this.originStateName,
    required this.destinationStateName,
    required this.originColor,
    required this.destinationColor,
    this.modulo,
    this.triggerCode = 'MANUAL',
    this.onDelete,
    this.onEdit,
    this.canDelete = true,
    this.canEdit = true,
  });

  @override
  State<TransitionCard> createState() => _TransitionCardState();
}

class _TransitionCardState extends State<TransitionCard> {
  bool _isHovered = false;

  IconData _getTriggerIcon(String code) {
    switch (code) {
      case 'FIRMA_CLIENTE':
        return Icons.draw;
      case 'FOTO_SUBIDA':
        return Icons.camera_alt;
      case 'OS_REPUESTOS':
        return Icons.build_circle;
      case 'ASIGNAR_PERSONAL':
        return Icons.people_outline;
      case 'MANUAL':
      default:
        return Icons.touch_app;
    }
  }

  Color _getTriggerColor(String code) {
    switch (code) {
      case 'FIRMA_CLIENTE':
        return Colors.blue;
      case 'FOTO_SUBIDA':
        return Colors.purple;
      case 'OS_REPUESTOS':
        return Colors.orange;
      case 'ASIGNAR_PERSONAL':
        return Colors.teal;
      case 'MANUAL':
      default:
        return WorkflowTheme.textSecondary;
    }
  }

  String _getTriggerName(String code) {
    switch (code) {
      case 'FIRMA_CLIENTE':
        return 'Firma de Cliente';
      case 'FOTO_SUBIDA':
        return 'Foto de Evidencia';
      case 'OS_REPUESTOS':
        return 'OS Repuestos';
      case 'ASIGNAR_PERSONAL':
        return 'Asignar Personal';
      case 'MANUAL':
      default:
        return 'Manual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final originColor = WorkflowTheme.parseColor(widget.originColor);
    final destinationColor = WorkflowTheme.parseColor(widget.destinationColor);
    final triggerIcon = _getTriggerIcon(widget.triggerCode);
    final triggerColor = _getTriggerColor(widget.triggerCode);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: WorkflowDesignConstants.animationFast,
        // Eliminamos el height fijo para permitir expansion
        margin: const EdgeInsets.only(
          bottom: WorkflowDesignConstants.spacingSm,
        ),
        decoration: WorkflowTheme.cardDecoration(
          borderColor: _isHovered ? WorkflowTheme.primaryPurple : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(WorkflowDesignConstants.spacingMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Columna Izquierda: Icono Trigger (Solo en servicio)
              if (widget.modulo == 'servicio') ...[
                Tooltip(
                  message: 'Trigger: ${_getTriggerName(widget.triggerCode)}',
                  child: Icon(
                    triggerIcon,
                    size: WorkflowDesignConstants.iconSm,
                    color: triggerColor,
                  ),
                ),
                const SizedBox(width: WorkflowDesignConstants.spacingMd),
              ],

              // Columna Central: Puntos y Nombres (Acomodo vertical)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicadores visuales
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: originColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(
                          width: WorkflowDesignConstants.spacingXs,
                        ),
                        Icon(
                          Icons.arrow_forward,
                          size: WorkflowDesignConstants.iconXs, // Más pequeño
                          color: WorkflowTheme.textSecondary,
                        ),
                        const SizedBox(
                          width: WorkflowDesignConstants.spacingXs,
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: destinationColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: WorkflowDesignConstants.spacingXs),
                    // Nombres (Sin elipsis, permitiendo wrap)
                    Flexible(
                      child: Text(
                        '${widget.originStateName} → ${widget.destinationStateName}',
                        style: WorkflowTheme.bodyText.copyWith(
                          fontSize: WorkflowDesignConstants.textXs,
                          fontWeight: FontWeight.w500,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),

              // Acciones
              if (_isHovered)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.canEdit && widget.onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        iconSize: WorkflowDesignConstants.iconSm,
                        color: WorkflowTheme.info,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onEdit,
                      ),
                    const SizedBox(width: WorkflowDesignConstants.spacingSm),
                    if (widget.canDelete && widget.onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        iconSize: WorkflowDesignConstants.iconSm,
                        color: WorkflowTheme.error,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onDelete,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
