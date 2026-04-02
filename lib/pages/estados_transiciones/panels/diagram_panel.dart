import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';


/// Panel central que muestra el diagrama interactivo del workflow
class DiagramPanel extends StatefulWidget {
  final List<Map<String, dynamic>> estados;
  final List<Map<String, dynamic>> transiciones;
  final bool modoEdicion;
  final ValueChanged<bool> onModoEdicionChanged;
  final bool isLoading;
  final String? error;
  final Widget? diagramWidget;
  final VoidCallback? onAutoLayout;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onResetZoom;
  final double currentZoom;

  const DiagramPanel({
    super.key,
    required this.estados,
    required this.transiciones,
    required this.modoEdicion,
    required this.onModoEdicionChanged,
    required this.isLoading,
    this.error,
    this.diagramWidget,
    this.onAutoLayout,
    this.onZoomIn,
    this.onZoomOut,
    this.onResetZoom,
    this.currentZoom = 1.0,
  });

  @override
  State<DiagramPanel> createState() => _DiagramPanelState();
}

class _DiagramPanelState extends State<DiagramPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: WorkflowTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header con controles
          Container(
            padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
            decoration: BoxDecoration(
              color: WorkflowTheme.background,
              border: Border(
                bottom: BorderSide(
                  color: WorkflowTheme.border,
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(WorkflowDesignConstants.radiusLg),
                topRight: Radius.circular(WorkflowDesignConstants.radiusLg),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree,
                    color: WorkflowTheme.primaryPurple,
                    size: WorkflowDesignConstants.iconLg,
                  ),
                  const SizedBox(width: WorkflowDesignConstants.spacingMd),
                  const Text(
                    'Diagrama de Flujo',
                    style: TextStyle(
                      fontSize: WorkflowDesignConstants.textMd,
                      fontWeight: WorkflowDesignConstants.fontBold,
                      color: WorkflowTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: WorkflowDesignConstants.spacingLg),
                  
                  // Toggle modo edición
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WorkflowDesignConstants.spacingMd,
                      vertical: WorkflowDesignConstants.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: widget.modoEdicion
                          ? WorkflowTheme.primaryPurple.withOpacity(0.1)
                          : WorkflowTheme.surface,
                      borderRadius: BorderRadius.circular(
                        WorkflowDesignConstants.radiusMd,
                      ),
                      border: Border.all(
                        color: widget.modoEdicion
                            ? WorkflowTheme.primaryPurple
                            : WorkflowTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit,
                          size: WorkflowDesignConstants.iconSm,
                          color: widget.modoEdicion
                              ? WorkflowTheme.primaryPurple
                              : WorkflowTheme.textSecondary,
                        ),
                        const SizedBox(width: WorkflowDesignConstants.spacingSm),
                        Text(
                          'Modo Edición',
                          style: WorkflowTheme.caption.copyWith(
                            color: widget.modoEdicion
                                ? WorkflowTheme.primaryPurple
                                : WorkflowTheme.textSecondary,
                            fontWeight: WorkflowDesignConstants.fontMedium,
                          ),
                        ),
                        const SizedBox(width: WorkflowDesignConstants.spacingSm),
                        Switch(
                          value: widget.modoEdicion,
                          onChanged: widget.onModoEdicionChanged,
                          activeThumbColor: WorkflowTheme.primaryPurple,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: WorkflowDesignConstants.spacingMd),
                  
                  // Controles de zoom
                  Container(
                    decoration: BoxDecoration(
                      color: WorkflowTheme.surface,
                      borderRadius: BorderRadius.circular(
                        WorkflowDesignConstants.radiusMd,
                      ),
                      border: Border.all(color: WorkflowTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          iconSize: WorkflowDesignConstants.iconMd,
                          tooltip: 'Alejar',
                          onPressed: widget.onZoomOut,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: WorkflowDesignConstants.spacingSm,
                          ),
                          child: Text(
                            '${((widget.currentZoom) * 100).toInt()}%',
                            style: WorkflowTheme.caption.copyWith(
                              fontWeight: WorkflowDesignConstants.fontMedium,
                            ),
                          ),
                        ),
                        // Botón Zoom In
                        IconButton(
                          icon: const Icon(Icons.add),
                          iconSize: WorkflowDesignConstants.iconMd,
                          tooltip: 'Acercar',
                          onPressed: widget.onZoomIn,
                        ),
                        // Botón Reset Zoom
                        if (widget.onResetZoom != null)
                          IconButton(
                            icon: const Icon(Icons.zoom_out_map),
                            iconSize: WorkflowDesignConstants.iconMd,
                            tooltip: 'Restablecer Zoom',
                            onPressed: widget.onResetZoom,
                          ),
                        // Botón Auto-Layout (Varita mágica)
                        if (widget.onAutoLayout != null)
                          IconButton(
                            icon: const Icon(Icons.auto_fix_high),
                            iconSize: WorkflowDesignConstants.iconMd,
                            tooltip: 'Reorganizar automáticamente',
                            onPressed: widget.onAutoLayout,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instrucciones en modo edición
          if (widget.modoEdicion)
            Container(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacingMd),
              decoration: BoxDecoration(
                color: WorkflowTheme.info.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: WorkflowTheme.info.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: WorkflowDesignConstants.iconMd,
                    color: WorkflowTheme.info,
                  ),
                  const SizedBox(width: WorkflowDesignConstants.spacingMd),
                  Expanded(
                    child: Text(
                      'Arrastra desde un estado hacia otro para crear transición',
                      style: WorkflowTheme.caption.copyWith(
                        color: WorkflowTheme.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Área del diagrama
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: WorkflowTheme.error,
                              ),
                              const SizedBox(height: WorkflowDesignConstants.spacingMd),
                              Text(
                                'Error al cargar el diagrama',
                                style: WorkflowTheme.subtitle.copyWith(
                                  color: WorkflowTheme.error,
                                ),
                              ),
                              const SizedBox(height: WorkflowDesignConstants.spacingSm),
                              Text(
                                widget.error!,
                                style: WorkflowTheme.caption,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : widget.estados.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_tree,
                                    size: 64,
                                    color: WorkflowTheme.textDisabled,
                                  ),
                                  const SizedBox(height: WorkflowDesignConstants.spacingMd),
                                  Text(
                                    'No hay estados para mostrar',
                                    style: WorkflowTheme.subtitle.copyWith(
                                      color: WorkflowTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: WorkflowDesignConstants.spacingSm),
                                  Text(
                                    'Crea estados en el panel izquierdo para comenzar',
                                    style: WorkflowTheme.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : widget.diagramWidget ?? _buildPlaceholderDiagram(),
          ),

          // Footer con información
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: WorkflowDesignConstants.spacing,
              vertical: WorkflowDesignConstants.spacingSm,
            ),
            decoration: BoxDecoration(
              color: WorkflowTheme.surface,
              border: Border(
                top: BorderSide(
                  color: WorkflowTheme.border,
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(WorkflowDesignConstants.radiusLg),
                bottomRight: Radius.circular(WorkflowDesignConstants.radiusLg),
              ),
            ),
            child: Row(
              children: [
                _buildInfoChip(
                  icon: Icons.circle,
                  label: '${widget.estados.length} Estados',
                  color: WorkflowTheme.info,
                ),
                const SizedBox(width: WorkflowDesignConstants.spacingMd),
                _buildInfoChip(
                  icon: Icons.arrow_forward,
                  label: '${widget.transiciones.length} Transiciones',
                  color: WorkflowTheme.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkflowDesignConstants.spacingSm,
        vertical: WorkflowDesignConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(WorkflowDesignConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: WorkflowDesignConstants.iconSm,
            color: color,
          ),
          const SizedBox(width: WorkflowDesignConstants.spacingXs),
          Text(
            label,
            style: WorkflowTheme.caption.copyWith(
              color: color,
              fontWeight: WorkflowDesignConstants.fontMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderDiagram() {
    // Placeholder simple que muestra los estados en una lista horizontal
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WorkflowDesignConstants.spacingLg),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.estados.map((estado) {
          final color = WorkflowTheme.parseColor(estado['color'] ?? '#808080');
          return Container(
            margin: const EdgeInsets.only(
              right: WorkflowDesignConstants.spacing,
            ),
            padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
            width: WorkflowDesignConstants.diagramNodeWidth,
            height: WorkflowDesignConstants.diagramNodeHeight,
            decoration: BoxDecoration(
              color: WorkflowTheme.background,
              borderRadius: BorderRadius.circular(
                WorkflowDesignConstants.radiusMd,
              ),
              border: Border(
                left: BorderSide(
                  color: color,
                  width: WorkflowDesignConstants.cardBorderWidth,
                ),
                top: BorderSide(color: WorkflowTheme.border),
                right: BorderSide(color: WorkflowTheme.border),
                bottom: BorderSide(color: WorkflowTheme.border),
              ),
              boxShadow: WorkflowDesignConstants.shadowMd,
            ),
            child: Center(
              child: Text(
                estado['nombre_estado'] ?? 'Sin nombre',
                style: WorkflowTheme.bodyText.copyWith(
                  fontWeight: WorkflowDesignConstants.fontSemiBold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
