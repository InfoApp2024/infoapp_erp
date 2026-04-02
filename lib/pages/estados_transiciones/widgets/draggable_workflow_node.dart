import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';

/// Widget que representa un nodo arrastrable en el diagrama de workflow
class DraggableWorkflowNode extends StatefulWidget {
  final String id;
  final String name;
  final Color color;
  final bool isInitial;
  final bool isFinal;
  final bool requiresSignature;
  final Offset position;
  final bool isDraggable;
  final Function(String id, Offset newPosition)? onPositionChanged;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isSelected;
  final String? modulo;

  const DraggableWorkflowNode({
    super.key,
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    this.modulo,
    this.isInitial = false,
    this.isFinal = false,
    this.requiresSignature = false,
    this.isDraggable = false,
    this.onPositionChanged,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isSelected = false,
  });

  @override
  State<DraggableWorkflowNode> createState() => _DraggableWorkflowNodeState();
}

class _DraggableWorkflowNodeState extends State<DraggableWorkflowNode> {
  bool _isHovered = false;
  Offset? _dragOffset;

  @override
  Widget build(BuildContext context) {
    const nodeWidth = 180.0;
    const nodeHeight = 80.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: widget.position.dx - nodeWidth / 2,
      top: widget.position.dy - nodeHeight / 2,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: widget.isDraggable ? _onPanStart : null,
        onPanUpdate: widget.isDraggable ? _onPanUpdate : null,
        onPanEnd: widget.isDraggable ? _onPanEnd : null,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: widget.isDraggable
              ? SystemMouseCursors.grab
              : SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: WorkflowDesignConstants.animationFast,
            width: nodeWidth,
            height: nodeHeight,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(WorkflowDesignConstants.radiusMd),
              border: Border.all(
                color: widget.isSelected
                    ? WorkflowTheme.primaryPurple
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.2 : 0.1),
                  blurRadius: _isHovered ? 12 : 8,
                  offset: Offset(0, _isHovered ? 6 : 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Contenido del nodo
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Nombre del estado
                      Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Badges (Solo en servicio)
                      if (widget.modulo == 'servicio')
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          if (widget.isInitial)
                            _buildMiniTag('Inicial', WorkflowTheme.success),
                          if (widget.isFinal)
                            _buildMiniTag('Final', WorkflowTheme.error),
                          if (widget.requiresSignature)
                            _buildMiniTag('Firma', WorkflowTheme.warning),
                        ],
                      ),
                    ],
                  ),
                ),

                // Botones de acción (visible al hover)
                if (_isHovered && (widget.onEdit != null || widget.onDelete != null))
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onEdit != null)
                          _buildActionButton(
                            Icons.edit,
                            WorkflowTheme.info,
                            widget.onEdit!,
                          ),
                        if (widget.onDelete != null)
                          _buildActionButton(
                            Icons.delete,
                            WorkflowTheme.error,
                            widget.onDelete!,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: WorkflowDesignConstants.shadowSm,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    _dragOffset = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragOffset == null) return;

    final newPosition = Offset(
      widget.position.dx + details.delta.dx,
      widget.position.dy + details.delta.dy,
    );

    widget.onPositionChanged?.call(widget.id, newPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragOffset = null;
  }
}
