import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';
import '../widgets/state_card.dart';
import '../dialogs/create_state_dialog.dart';

/// Panel izquierdo que muestra la lista de estados
class StatesPanel extends StatefulWidget {
  final List<Map<String, dynamic>> estados;
  final List<Map<String, dynamic>> estadosBase;
  final bool isLoading;
  final String? error;
  final String modulo;
  final Function(Map<String, dynamic>) onCreateState;
  final Function(int id, String nombre) onEditState;
  final Function(int id) onDeleteState;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const StatesPanel({
    super.key,
    required this.estados,
    required this.estadosBase,
    this.isLoading = false,
    this.error,
    required this.modulo,
    required this.onCreateState,
    required this.onEditState,
    required this.onDeleteState,
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
  });

  @override
  State<StatesPanel> createState() => _StatesPanelState();
}

class _StatesPanelState extends State<StatesPanel> {
  String _searchQuery = '';
  bool _modoCompacto = false;

  List<Map<String, dynamic>> get _estadosFiltrados {
    if (_searchQuery.isEmpty) return widget.estados;

    return widget.estados.where((estado) {
      final nombre = (estado['nombre_estado'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return nombre.contains(query);
    }).toList();
  }

  /// Identifica los IDs de los estados "Oficiales" o "De Sistema"
  /// para protegerlos de la eliminación. Protege exactamente uno por cada código core.
  Set<int> get _officialStateIds {
    final Set<int> protectedIds = {};

    // Los 7 códigos core que el sistema requiere
    const coreCodes = {
      'ABIERTO',
      'PROGRAMADO',
      'ASIGNADO',
      'EN_EJECUCION',
      'FINALIZADO',
      'LEGALIZADO',
      'CERRADO',
      'CANCELADO',
    };

    // Para cada código, buscaremos el mejor representante
    for (final code in coreCodes) {
      int? bestId;
      bool bestIsNameMatch = false;

      for (final estado in widget.estados) {
        final currentCode =
            (estado['estado_base_codigo'] ?? '').toString().toUpperCase();
        if (currentCode != code) continue;

        final id = int.tryParse(estado['id'].toString());
        if (id == null) continue;

        final nombre = (estado['nombre_estado'] ?? '').toString().toLowerCase();
        final baseNombre =
            (estado['estado_base_nombre'] ?? '').toString().toLowerCase();

        // Prioridad 1: Coincidencia exacta de nombre
        final isNameMatch = nombre == baseNombre;

        if (bestId == null) {
          bestId = id;
          bestIsNameMatch = isNameMatch;
        } else {
          // Si este coincide en nombre y el anterior no, este es mejor
          if (isNameMatch && !bestIsNameMatch) {
            bestId = id;
            bestIsNameMatch = true;
          }
          // Si ambos coinciden (o ninguno), preferimos el ID más bajo
          else if (isNameMatch == bestIsNameMatch) {
            if (id < bestId) {
              bestId = id;
            }
          }
        }
      }

      if (bestId != null) {
        protectedIds.add(bestId);
      }
    }

    return protectedIds;
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder:
          (context) => CreateStateDialog(
            estadosBase: widget.estadosBase,
            onCreate: widget.onCreateState,
            modulo: widget.modulo,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: WorkflowTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header del panel
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
                  Icons.list_alt,
                  color: Colors.white,
                  size: WorkflowDesignConstants.iconLg,
                ),
                const SizedBox(width: WorkflowDesignConstants.spacingMd),
                const Expanded(
                  child: Text(
                    'Estados del Workflow',
                    style: TextStyle(
                      fontSize: WorkflowDesignConstants.textMd,
                      fontWeight: WorkflowDesignConstants.fontBold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _modoCompacto ? Icons.view_list : Icons.view_compact,
                    color: Colors.white,
                  ),
                  tooltip: _modoCompacto ? 'Vista detallada' : 'Vista compacta',
                  onPressed: () {
                    setState(() => _modoCompacto = !_modoCompacto);
                  },
                ),
              ],
            ),
          ),

          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar estado...',
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

          // Lista de estados
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
                    : _estadosFiltrados.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(
                          WorkflowDesignConstants.spacing,
                        ),
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No hay estados creados'
                              : 'No se encontraron estados',
                          style: WorkflowTheme.bodyTextSecondary,
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: WorkflowDesignConstants.spacing,
                      ),
                      itemCount: _estadosFiltrados.length,
                      itemBuilder: (context, index) {
                        final estado = _estadosFiltrados[index];
                        final id = int.tryParse(estado['id'].toString());

                        // Determinar propiedades del estado
                        final nombre = estado['nombre_estado'] ?? 'Sin nombre';
                        final color = estado['color'] ?? '#808080';
                        final estadoBase = estado['estado_base_codigo'];
                        final orden = int.tryParse(
                          estado['orden']?.toString() ?? '0',
                        );
                        final bloqueaCierre =
                            (int.tryParse(
                                  estado['bloquea_cierre']?.toString() ?? '0',
                                ) ??
                                0) ==
                            1;

                        // Determinar si es inicial o final (Badges visuales)
                        final isInitial = estadoBase == 'ABIERTO';
                        final isFinal =
                            (int.tryParse(
                                      estado['es_final']?.toString() ?? '0',
                                    ) ??
                                    0) ==
                                1 ||
                            estadoBase == 'CERRADO' ||
                            estadoBase == 'CANCELADO';

                        // Verificar si este ID específico es uno de los protegidos (Oficiales)
                        final isProtectedSystemState = _officialStateIds
                            .contains(id);

                        return StateCard(
                          id:
                              estado['id']
                                  .toString(), // Keep original id type as String
                          name: nombre,
                          color: color,
                          modulo: widget.modulo,
                          isInitial: isInitial, // Keep original property name
                          isFinal: isFinal, // Keep original property name
                          blocksClosure: bloqueaCierre,
                          estadoBase: estadoBase,
                          orden: orden,
                          // New properties from instruction, assuming they are defined elsewhere or will be added
                          // requiresSignature: requiereFirma, // This variable is not defined
                          // transitionCount: transitionCount, // This variable is not defined
                          onEdit:
                              widget.canEdit && id != null
                                  ? () => widget.onEditState(
                                    id,
                                    nombre,
                                  ) // Revert to original onEdit signature
                                  : null,
                          onDelete:
                              widget.canDelete &&
                                      id != null &&
                                      !isProtectedSystemState
                                  ? () => widget.onDeleteState(id)
                                  : null,
                          canEdit: widget.canEdit,
                          canDelete: widget.canDelete,
                        );
                      },
                    ),
          ),

          // Botón de crear nuevo estado
          if (widget.canCreate)
            Padding(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
              child: ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Estado'),
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
