import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';
import '../widgets/transition_card.dart';

/// Panel derecho que muestra la lista de transiciones
class TransitionsPanel extends StatefulWidget {
  final List<Map<String, dynamic>> transiciones;
  final List<Map<String, dynamic>> estados;
  final String? modulo;
  final bool isLoading;
  final String? error;
  final Function(int id) onDeleteTransition;
  final Function(int id, String? nombre, String? triggerCode)? onEditTransition;
  final VoidCallback? onCreateTransition;
  final bool canCreate;
  final bool canDelete;
  final bool canEdit;

  const TransitionsPanel({
    super.key,
    required this.transiciones,
    required this.estados,
    this.modulo,
    this.isLoading = false,
    this.error,
    required this.onDeleteTransition,
    this.onEditTransition,
    this.onCreateTransition,
    this.canCreate = true,
    this.canDelete = true,
    this.canEdit = true,
  });

  @override
  State<TransitionsPanel> createState() => _TransitionsPanelState();
}

class _TransitionsPanelState extends State<TransitionsPanel> {
  String _searchQuery = '';

  List<Map<String, dynamic>> get _transicionesFiltradas {
    if (_searchQuery.isEmpty) return widget.transiciones;

    return widget.transiciones.where((trans) {
      final origen = _getEstadoNombre(trans['estado_origen_id']);
      final destino = _getEstadoNombre(trans['estado_destino_id']);
      final query = _searchQuery.toLowerCase();

      return origen.toLowerCase().contains(query) ||
          destino.toLowerCase().contains(query);
    }).toList();
  }

  String _getEstadoNombre(dynamic estadoId) {
    if (estadoId == null) return 'Desconocido';

    final id = estadoId.toString();
    final estado = widget.estados.firstWhere(
      (e) => e['id'].toString() == id,
      orElse: () => {},
    );

    return estado['nombre_estado'] ?? 'Desconocido';
  }

  String _getEstadoColor(dynamic estadoId) {
    if (estadoId == null) return '#808080';

    final id = estadoId.toString();
    final estado = widget.estados.firstWhere(
      (e) => e['id'].toString() == id,
      orElse: () => {},
    );

    return estado['color'] ?? '#808080';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: WorkflowTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
            decoration: BoxDecoration(
              gradient: WorkflowTheme.purpleGradient(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(WorkflowDesignConstants.radiusLg),
                topRight: Radius.circular(WorkflowDesignConstants.radiusLg),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: WorkflowDesignConstants.iconLg,
                ),
                const SizedBox(width: WorkflowDesignConstants.spacingMd),
                const Expanded(
                  child: Text(
                    'Transiciones Activas',
                    style: TextStyle(
                      fontSize: WorkflowDesignConstants.textMd,
                      fontWeight: WorkflowDesignConstants.fontBold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${widget.transiciones.length}',
                  style: const TextStyle(
                    fontSize: WorkflowDesignConstants.textLg,
                    fontWeight: WorkflowDesignConstants.fontBold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar transición...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    WorkflowDesignConstants.radiusMd,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: WorkflowDesignConstants.spacing,
                  vertical: WorkflowDesignConstants.spacingMd,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Lista de transiciones
          Expanded(
            child:
                widget.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : widget.error != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(
                          WorkflowDesignConstants.spacing,
                        ),
                        child: Text(
                          'Error: ${widget.error}',
                          style: WorkflowTheme.bodyText.copyWith(
                            color: WorkflowTheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : _transicionesFiltradas.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(
                          WorkflowDesignConstants.spacing,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              size: 48,
                              color: WorkflowTheme.textDisabled,
                            ),
                            const SizedBox(
                              height: WorkflowDesignConstants.spacingMd,
                            ),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No hay transiciones creadas'
                                  : 'No se encontraron transiciones',
                              style: WorkflowTheme.bodyTextSecondary,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: WorkflowDesignConstants.spacing,
                      ),
                      itemCount: _transicionesFiltradas.length,
                      itemBuilder: (context, index) {
                        final trans = _transicionesFiltradas[index];
                        final id = int.tryParse(trans['id'].toString());

                        final origenNombre = _getEstadoNombre(
                          trans['estado_origen_id'],
                        );
                        final destinoNombre = _getEstadoNombre(
                          trans['estado_destino_id'],
                        );
                        final origenColor = _getEstadoColor(
                          trans['estado_origen_id'],
                        );
                        final destinoColor = _getEstadoColor(
                          trans['estado_destino_id'],
                        );

                        return TransitionCard(
                          id: trans['id'].toString(),
                          modulo: widget.modulo,
                          originStateName: origenNombre,
                          destinationStateName: destinoNombre,
                          originColor: origenColor,
                          destinationColor: destinoColor,
                          triggerCode: trans['trigger_code'] ?? 'MANUAL',
                          onDelete:
                              widget.canDelete && id != null
                                  ? () => widget.onDeleteTransition(id)
                                  : null,
                          onEdit:
                              widget.canEdit &&
                                      id != null &&
                                      widget.onEditTransition != null
                                  ? () => widget.onEditTransition!(
                                    id,
                                    trans['nombre'],
                                    trans['trigger_code'],
                                  )
                                  : null,
                          canDelete: widget.canDelete,
                          canEdit: widget.canEdit,
                        );
                      },
                    ),
          ),

          // Botón de crear nueva transición
          if (widget.canCreate && widget.onCreateTransition != null)
            Padding(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
              child: ElevatedButton.icon(
                onPressed: widget.onCreateTransition,
                icon: const Icon(Icons.add),
                label: const Text('Nueva Transición'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WorkflowTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: WorkflowDesignConstants.spacing,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      WorkflowDesignConstants.radiusMd,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
