import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';
import 'state_badge.dart';

/// Card mejorado para mostrar un estado del workflow
class StateCard extends StatefulWidget {
  final String id;
  final String name;
  final String color;
  final bool isInitial;
  final bool isFinal;
  final bool requiresSignature;
  final bool blocksClosure;
  final String? modulo;
  final String? estadoBase;
  final int? orden;
  final int? transitionCount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool canEdit;
  final bool canDelete;

  const StateCard({
    super.key,
    required this.id,
    required this.name,
    required this.color,
    this.modulo,
    this.isInitial = false,
    this.isFinal = false,
    this.requiresSignature = false,
    this.blocksClosure = false,
    this.estadoBase,
    this.orden,
    this.transitionCount,
    this.onEdit,
    this.onDelete,
    this.canEdit = true,
    this.canDelete = true,
  });

  @override
  State<StateCard> createState() => _StateCardState();
}

class _StateCardState extends State<StateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final stateColor = WorkflowTheme.parseColor(widget.color);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: WorkflowDesignConstants.animationFast,
        height: WorkflowDesignConstants.stateCardHeight,
        margin: const EdgeInsets.only(
          bottom: WorkflowDesignConstants.spacingSm,
        ),
        decoration: WorkflowTheme.cardDecorationWithLeftBorder(stateColor),
        child: Padding(
          padding: const EdgeInsets.all(WorkflowDesignConstants.spacingMd),
          child: Row(
            children: [
              // Indicador de color circular
              Container(
                width: WorkflowDesignConstants.colorIndicatorSize,
                height: WorkflowDesignConstants.colorIndicatorSize,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: WorkflowDesignConstants.spacingMd),
              
              // Contenido principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Nombre y badges
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.name,
                            style: WorkflowTheme.bodyText.copyWith(
                              fontWeight: WorkflowDesignConstants.fontSemiBold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Badges más compactos (Solo en servicio)
                        if (widget.modulo == 'servicio' && (widget.isInitial ||
                            widget.isFinal ||
                            widget.requiresSignature)) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.isInitial)
                                  Flexible(child: StateBadge.initial()),
                                if (widget.isFinal) ...[
                                  const SizedBox(width: 2),
                                  Flexible(child: StateBadge.final_()),
                                ],
                                if (widget.requiresSignature) ...[
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: StateBadge.requiresSignature(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: WorkflowDesignConstants.spacingXs),
                    
                    // Información secundaria (Solo en servicio)
                    if (widget.modulo == 'servicio')
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (widget.estadoBase != null) ...[
                            Text(
                              'Base: ${widget.estadoBase}',
                              style: WorkflowTheme.caption,
                            ),
                            const SizedBox(
                              width: WorkflowDesignConstants.spacingMd,
                            ),
                          ],
                          if (widget.orden != null) ...[
                            Text(
                              'Orden: ${widget.orden}',
                              style: WorkflowTheme.caption,
                            ),
                            const SizedBox(
                              width: WorkflowDesignConstants.spacingMd,
                            ),
                          ],
                          if (widget.transitionCount != null &&
                              widget.transitionCount! > 0)
                            Text(
                              '${widget.transitionCount} transiciones',
                              style: WorkflowTheme.caption,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Acciones (siempre visibles para mejor UX)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.canEdit && widget.onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      iconSize: WorkflowDesignConstants.iconMd,
                      color: WorkflowTheme.info,
                      tooltip: 'Editar estado',
                      onPressed: widget.onEdit,
                    ),
                  if (widget.canDelete && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      iconSize: WorkflowDesignConstants.iconMd,
                      color: WorkflowTheme.error,
                      tooltip: 'Eliminar estado',
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
