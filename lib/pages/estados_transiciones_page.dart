import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'servicios/services/estados_service.dart';
import '../core/enums/modulo_enum.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';

// Nuevos imports para componentes del diseño
import 'estados_transiciones/design/workflow_theme.dart';
import 'estados_transiciones/design/design_constants.dart';
import 'estados_transiciones/widgets/module_selector.dart';
import 'estados_transiciones/panels/states_panel.dart';
import 'estados_transiciones/panels/diagram_panel.dart';
import 'estados_transiciones/panels/transitions_panel.dart';
import 'estados_transiciones/dialogs/edit_state_dialog.dart';
import 'estados_transiciones/dialogs/transition_configuration_dialog.dart';
import 'estados_transiciones/dialogs/confirm_delete_dialog.dart';
import 'estados_transiciones/painters/grid_background_painter.dart';
import 'estados_transiciones/painters/connections_painter.dart';
import 'estados_transiciones/painters/temporary_connection_painter.dart';
import 'estados_transiciones/widgets/draggable_workflow_node.dart';
import 'estados_transiciones/widgets/mini_map_widget.dart';

/// Página principal de gestión de Estados y Transiciones
/// Versión refactorizada con nuevo diseño UI/UX
class EstadosTransicionesPage extends StatefulWidget {
  const EstadosTransicionesPage({super.key});

  @override
  State<EstadosTransicionesPage> createState() =>
      _EstadosTransicionesPageState();
}

class _EstadosTransicionesPageState extends State<EstadosTransicionesPage> {
  // ============================================================================
  // ESTADO Y DATOS
  // ============================================================================

  List<Map<String, dynamic>> _estados = [];
  List<Map<String, dynamic>> _transiciones = [];
  List<Map<String, dynamic>> _estadosBase = [];

  bool _isLoadingEstados = false;
  bool _isLoadingTransiciones = false;
  String? _errorEstados;
  String? _errorTransiciones;

  ModuloEnum _moduloSeleccionado = ModuloEnum.servicios;
  final bool _modoEdicionDiagrama = false;

  // Estado del diagrama
  final TransformationController _diagramTransform = TransformationController();
  Map<String, Offset> _nodePositions = {};
  int? _diagramOrigenSeleccionado;
  Offset? _dragScenePos;
  int? _selectedTransitionId;
  bool _modoEdicion = false; // Modo edición para crear transiciones
  double _currentZoom = 1.0; // Zoom actual para sincronización

  // Permisos
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;

  // ============================================================================
  // INICIALIZACIÓN
  // ============================================================================

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _cargarDatos();

    // Escuchar cambios en el zoom
    _diagramTransform.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _diagramTransform.removeListener(_onZoomChanged);
    _diagramTransform.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final newZoom = _diagramTransform.value.getMaxScaleOnAxis();
    if ((newZoom - _currentZoom).abs() > 0.01) {
      setState(() {
        _currentZoom = newZoom;
      });
    }
  }

  void _loadPermissions() {
    final perms = PermissionStore.instance;
    setState(() {
      _canCreate = perms.can('estados_transiciones', 'crear');
      _canDelete = perms.can('estados_transiciones', 'eliminar');
      // Permiso específico para actualizar/editar
      _canEdit = perms.can('estados_transiciones', 'actualizar');
    });
  }

  /// Inicializa las posiciones de los nodos con layout jerárquico tipo Sugiyama
  void _initializeNodePositions() {
    if (_estados.isEmpty) return;

    final Map<String, Offset> positions = {};

    // Implementar layout jerárquico basado en transiciones
    positions.addAll(_calculateSugiyamaLayout());

    setState(() {
      _nodePositions = positions;
    });
  }

  /// Calcula layout jerárquico tipo Sugiyama
  Map<String, Offset> _calculateSugiyamaLayout() {
    final Map<String, Offset> positions = {};
    final Map<String, int> levels = {}; // Nivel jerárquico de cada nodo
    final Map<String, List<String>> outgoing = {}; // Transiciones salientes
    final Map<String, List<String>> incoming = {}; // Transiciones entrantes

    // Construir grafo de dependencias
    for (final transicion in _transiciones) {
      final origen = transicion['estado_origen_id']?.toString();
      final destino = transicion['estado_destino_id']?.toString();

      if (origen != null && destino != null) {
        outgoing.putIfAbsent(origen, () => []).add(destino);
        incoming.putIfAbsent(destino, () => []).add(origen);
      }
    }

    // Encontrar nodos raíz (estados iniciales sin padres)
    final allNodes = _estados.map((e) => e['id'].toString()).toSet();
    final nodesWithParents = incoming.keys.toSet();
    final rootNodes = allNodes.difference(nodesWithParents).toList();

    // Si no hay raíz clara, buscar por orden o nombre
    if (rootNodes.isEmpty && _estados.isNotEmpty) {
      // Buscar estado con orden 0 o nombre "ABIERTO"
      for (final estado in _estados) {
        final nombre = estado['nombre_estado']?.toString().toUpperCase() ?? '';
        final orden = int.tryParse(estado['orden']?.toString() ?? '999');
        if (orden == 0 ||
            nombre.contains('ABIERTO') ||
            nombre.contains('INICIAL')) {
          rootNodes.add(estado['id'].toString());
          break;
        }
      }
      // Si aún no hay raíz, usar el primero
      if (rootNodes.isEmpty) {
        rootNodes.add(_estados.first['id'].toString());
      }
    }

    // Asignar niveles usando BFS (Breadth-First Search)
    final queue = <String>[];
    for (final root in rootNodes) {
      levels[root] = 0;
      queue.add(root);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentLevel = levels[current]!;

      final children = outgoing[current] ?? [];
      for (final child in children) {
        if (!levels.containsKey(child)) {
          levels[child] = currentLevel + 1;
          queue.add(child);
        }
      }
    }

    // Asignar nivel 0 a nodos sin conexión
    for (final estado in _estados) {
      final id = estado['id'].toString();
      if (!levels.containsKey(id)) {
        levels[id] = 0;
      }
    }

    // Agrupar nodos por nivel
    final Map<int, List<String>> nodesByLevel = {};
    levels.forEach((id, level) {
      nodesByLevel.putIfAbsent(level, () => []).add(id);
    });

    // Calcular posiciones con espaciado jerárquico
    const double horizontalSpacing = 350.0; // Espacio entre niveles
    const double verticalSpacing = 180.0; // Espacio entre nodos del mismo nivel
    const double marginLeft = 250.0;
    const double marginTop = 200.0;

    nodesByLevel.forEach((level, nodes) {
      // Centrar verticalmente los nodos de cada nivel
      final totalHeight = (nodes.length - 1) * verticalSpacing;
      final startY =
          marginTop + 1000 - totalHeight / 2; // Centrar en canvas de 5000

      for (int i = 0; i < nodes.length; i++) {
        final id = nodes[i];
        positions[id] = Offset(
          marginLeft + level * horizontalSpacing,
          startY + i * verticalSpacing,
        );
      }
    });

    return positions;
  }

  // ============================================================================
  // CARGA DE DATOS
  // ============================================================================

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoadingEstados = true;
      _isLoadingTransiciones = true;
    });

    await Future.wait([
      _cargarEstados(),
      _cargarTransiciones(),
      _cargarEstadosBase(),
    ]);

    // Centrar vista al finalizar carga
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerView();
      });
    }
  }

  Future<void> _cargarEstadosBase() async {
    final url =
        '${ServerConfig.instance.baseUrlFor('workflow')}/listar_estados_base.php';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dynamic data = _decodeFlexible(response.body.trim());
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['estados_base'] is List) {
          list = data['estados_base'];
        }

        if (list.isNotEmpty) {
          setState(() {
            _estadosBase =
                list.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        } else {
          // Fallback local
          setState(() {
            _estadosBase = [
              {'codigo': 'ABIERTO', 'nombre': 'Abierto', 'es_final': 0},
              {'codigo': 'PROGRAMADO', 'nombre': 'Programado', 'es_final': 0},
              {
                'codigo': 'EN_EJECUCION',
                'nombre': 'En Ejecución',
                'es_final': 0,
              },
              {'codigo': 'FINALIZADO', 'nombre': 'Finalizado', 'es_final': 1},
              {'codigo': 'CERRADO', 'nombre': 'Cerrado', 'es_final': 1},
              {'codigo': 'CANCELADO', 'nombre': 'Cancelado', 'es_final': 1},
            ];
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando estados base: $e');
    }
  }

  dynamic _decodeFlexible(String source) {
    if (source.isEmpty) return null;

    try {
      return json.decode(source);
    } catch (e) {
      try {
        return json.decode(utf8.decode(source.codeUnits));
      } catch (e2) {
        try {
          return json.decode(latin1.decode(source.codeUnits));
        } catch (e3) {
          debugPrint('Error decodificando JSON: $e3');
          return null;
        }
      }
    }
  }

  Future<void> _cargarEstados() async {
    setState(() {
      _isLoadingEstados = true;
      _errorEstados = null;
    });

    final url =
        '${ServerConfig.instance.baseUrlFor('workflow')}/listar_estados.php?modulo=${_moduloSeleccionado.key}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final dynamic data = _decodeFlexible(response.body.trim());

        List<Map<String, dynamic>> estados = [];

        if (data is List) {
          estados =
              data
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        } else if (data is Map && data['estados'] is List) {
          estados =
              (data['estados'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        } else if (data is Map && data['data'] is List) {
          estados =
              (data['data'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        }

        if (mounted) {
          setState(() {
            _estados = estados;
            _isLoadingEstados = false;
            _errorEstados = null;
          });
          // Inicializar posiciones de nodos después de cargar
          _initializeNodePositions();
        }
      } else {
        setState(() {
          _errorEstados = 'Error ${response.statusCode}';
          _isLoadingEstados = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorEstados = e.toString();
        _isLoadingEstados = false;
      });
    }
  }

  void _ensureNodePositions() {
    for (int i = 0; i < _estados.length; i++) {
      final id = _estados[i]['id'].toString();
      if (!_nodePositions.containsKey(id)) {
        _nodePositions[id] = Offset(100.0 + i * 200.0, 200.0);
      }
    }
  }

  Future<void> _cargarTransiciones() async {
    setState(() {
      _isLoadingTransiciones = true;
      _errorTransiciones = null;
    });

    final url =
        '${ServerConfig.instance.baseUrlFor('workflow')}/listar_transiciones.php?modulo=${_moduloSeleccionado.key}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final dynamic data = _decodeFlexible(response.body.trim());

        if (data is List) {
          setState(() {
            _transiciones =
                data
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
            _isLoadingTransiciones = false;
          });
        } else if (data is Map && data['transiciones'] is List) {
          setState(() {
            _transiciones =
                (data['transiciones'] as List)
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
            _isLoadingTransiciones = false;
          });
        } else if (data is Map && data['data'] is List) {
          setState(() {
            _transiciones =
                (data['data'] as List)
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
            _isLoadingTransiciones = false;
          });
        } else {
          // Si no hay formato reconocido, asumir lista vacía
          setState(() {
            _transiciones = [];
            _isLoadingTransiciones = false;
          });
        }
      } else {
        setState(() {
          _errorTransiciones = 'Error ${response.statusCode}';
          _isLoadingTransiciones = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorTransiciones = e.toString();
        _isLoadingTransiciones = false;
      });
    }
  }

  // ============================================================================
  // OPERACIONES CRUD - ESTADOS
  // ============================================================================

  /// Identifica los IDs de los estados "Oficiales" o "De Sistema"
  Set<int> get _officialStateIds {
    final Set<int> protectedIds = {};
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

    for (final code in coreCodes) {
      int? bestId;
      bool bestIsNameMatch = false;

      for (final estado in _estados) {
        final currentCode =
            (estado['estado_base_codigo'] ?? '').toString().toUpperCase();
        if (currentCode != code) continue;

        final id = int.tryParse(estado['id'].toString());
        if (id == null) continue;

        final nombre = (estado['nombre_estado'] ?? '').toString().toLowerCase();
        final baseNombre =
            (estado['estado_base_nombre'] ?? '').toString().toLowerCase();
        final isNameMatch = nombre == baseNombre;

        if (bestId == null ||
            (isNameMatch && !bestIsNameMatch) ||
            (isNameMatch == bestIsNameMatch && id < bestId)) {
          bestId = id;
          bestIsNameMatch = isNameMatch;
        }
      }
      if (bestId != null) protectedIds.add(bestId);
    }
    return protectedIds;
  }

  Future<void> _crearEstado(Map<String, dynamic> data) async {
    final url =
        '${ServerConfig.instance.baseUrlFor('workflow')}/crear_estado.php';

    try {
      final body = {...data, 'modulo': _moduloSeleccionado.key};

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Estado creado exitosamente'),
                backgroundColor: WorkflowTheme.success,
              ),
            );
          }
          await _cargarEstados();
        } else {
          throw Exception(result['message'] ?? 'Error desconocido');
        }
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final result = json.decode(response.body);
          if (result['message'] != null) errorMsg = result['message'];
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al crear estado: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: WorkflowTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editarEstado(int id, Map<String, dynamic> data) async {
    final url =
        '${ServerConfig.instance.baseUrlFor('workflow')}/editar_estado.php';

    try {
      final body = {'id': id, ...data, 'modulo': _moduloSeleccionado.key};

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Estado actualizado exitosamente'),
                backgroundColor: WorkflowTheme.success,
              ),
            );
          }
          await _cargarEstados();
        } else {
          throw Exception(result['message'] ?? 'Error desconocido');
        }
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final result = json.decode(response.body);
          if (result['message'] != null) errorMsg = result['message'];
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al actualizar estado: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: WorkflowTheme.error,
          ),
        );
      }
    }
  }

  void _mostrarDialogoEdicion(int id, String nombre) {
    final estado = _estados.firstWhere(
      (e) => int.tryParse(e['id'].toString()) == id,
      orElse: () => {},
    );

    if (estado.isEmpty) return;

    // Verificar si es uno de los 7 core protegidos
    final isProtected = _officialStateIds.contains(id);

    showDialog(
      context: context,
      builder:
          (context) => EditStateDialog(
            estado: estado,
            estadosBase: _estadosBase,
            isProtected: isProtected,
            modulo: _moduloSeleccionado.key,
            onUpdate: _editarEstado,
          ),
    );
  }

  Future<void> _eliminarEstado(int id) async {
    // Verificar transiciones
    final transiciones =
        _transiciones.where((t) {
          final origenId = int.tryParse(
            t['estado_origen_id']?.toString() ?? '',
          );
          final destinoId = int.tryParse(
            t['estado_destino_id']?.toString() ?? '',
          );
          return origenId == id || destinoId == id;
        }).toList();

    final estado = _estados.firstWhere(
      (e) => int.tryParse(e['id'].toString()) == id,
      orElse: () => {'nombre_estado': 'Desconocido'},
    );

    showDialog(
      context: context,
      builder:
          (context) => ConfirmDeleteDialog.deleteState(
            stateName: estado['nombre_estado'] ?? 'Desconocido',
            transitionCount: transiciones.length,
            onConfirm: () => _ejecutarEliminacionEstado(id),
          ),
    );
  }

  Future<void> _ejecutarEliminacionEstado(int id) async {
    final url =
        '${ServerConfig.instance.baseUrlFor('workflow')}/eliminar_estado.php';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id, 'modulo': _moduloSeleccionado.key}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Estado eliminado exitosamente'),
                backgroundColor: WorkflowTheme.success,
              ),
            );
          }
          await Future.wait([_cargarEstados(), _cargarTransiciones()]);
        } else {
          throw Exception(result['message'] ?? 'Error desconocido');
        }
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final result = json.decode(response.body);
          if (result['message'] != null) errorMsg = result['message'];
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar estado: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: WorkflowTheme.error,
          ),
        );
      }
    }
  }

  // ============================================================================
  // OPERACIONES CRUD - TRANSICIONES
  // ============================================================================

  /// Crea una transición desde el diagrama interactivo
  Future<void> _crearTransicionDiagrama(int origenId, int destinoId) async {
    await _crearTransicionDirect(origenId, destinoId);
    // Recalcular layout después de crear transición
    _initializeNodePositions();
  }

  Future<void> _crearTransicionDirect(int origenId, int destinoId) async {
    // Verificar si ya existe
    final existe = _transiciones.any((t) {
      return t['estado_origen_id'] == origenId &&
          t['estado_destino_id'] == destinoId;
    });

    if (existe) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta transición ya existe')),
        );
      }
      return;
    }

    final url =
        '${ServerConfig.instance.baseUrlFor('workflow')}/crear_transicion.php';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'modulo': _moduloSeleccionado.key,
          'estado_origen_id': origenId,
          'estado_destino_id': destinoId,
          'nombre': 'Transición',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await _cargarTransiciones();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transición creada exitosamente')),
            );
          }
          // Recalcular layout después de recargar transiciones
          _initializeNodePositions();
        } else {
          throw Exception(data['message'] ?? 'Error desconocido');
        }
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final result = json.decode(response.body);
          if (result['message'] != null) errorMsg = result['message'];
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error creando transición: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al crear transición: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: WorkflowTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _eliminarTransicion(int id) async {
    // Buscar nombres de los estados
    final transicion = _transiciones.firstWhere(
      (t) => t['id'] == id,
      orElse: () => {},
    );

    if (transicion.isEmpty) return;

    final origenId = transicion['estado_origen_id'];
    final destinoId = transicion['estado_destino_id'];

    final origenNombre =
        _estados.firstWhere(
          (e) => e['id'] == origenId,
          orElse: () => {'nombre_estado': 'Desconocido'},
        )['nombre_estado'];

    final destinoNombre =
        _estados.firstWhere(
          (e) => e['id'] == destinoId,
          orElse: () => {'nombre_estado': 'Desconocido'},
        )['nombre_estado'];

    showDialog(
      context: context,
      builder:
          (context) => ConfirmDeleteDialog.deleteTransition(
            originState: origenNombre,
            destinationState: destinoNombre,
            onConfirm: () => _ejecutarEliminacionTransicion(id),
          ),
    );
  }

  Future<void> _ejecutarEliminacionTransicion(int id) async {
    final url =
        '${ServerConfig.instance.baseUrlFor('workflow')}/eliminar_transicion.php';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await _cargarTransiciones();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transición eliminada')),
            );
          }
          // Recalcular layout después de eliminar transición
          _initializeNodePositions();
        } else {
          throw Exception(data['message'] ?? 'Error desconocido');
        }
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final result = json.decode(response.body);
          if (result['message'] != null) errorMsg = result['message'];
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error eliminando transición: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar transición: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: WorkflowTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editarTransicion(
    int id,
    String? nombre,
    String? triggerCode,
  ) async {
    // Obtener lista de triggers en uso por OTRAS transiciones
    final usedTriggers =
        _transiciones
            .where((t) => int.tryParse(t['id'].toString()) != id)
            .map((t) => (t['trigger_code'] ?? 'MANUAL').toString())
            .where((code) => code != 'MANUAL')
            .toList();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => TransitionConfigurationDialog(
            modulo: _moduloSeleccionado.key,
            initialName: nombre,
            initialTrigger: triggerCode,
            usedTriggers: usedTriggers,
          ),
    );

    if (result != null) {
      final nuevoNombre = result['nombre'];
      final nuevoTrigger = result['trigger_code'];

      final success = await EstadosService.editarTransicion(
        id,
        nuevoNombre,
        nuevoTrigger,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transición actualizada correctamente'),
            ),
          );
        }
        await _cargarTransiciones();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar la transición')),
          );
        }
      }
    }
  }

  // ============================================================================
  // UTILIDADES
  // ============================================================================

  String _obtenerNombreEstado(String estadoId) {
    final estado = _estados.firstWhere(
      (e) => e['id'].toString() == estadoId,
      orElse: () => {},
    );
    return estado['nombre_estado'] ?? 'Desconocido';
  }

  void _onModuloChanged(ModuloEnum? nuevoModulo) {
    if (nuevoModulo == null || nuevoModulo == _moduloSeleccionado) return;

    setState(() {
      _moduloSeleccionado = nuevoModulo;
      _estados = [];
      _transiciones = [];
      _nodePositions.clear();
    });

    _cargarDatos();
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (_modoEdicion && _diagramOrigenSeleccionado != null) {
          setState(() {
            _dragScenePos = event.localPosition;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estados y Transiciones'),
          backgroundColor: WorkflowTheme.primaryPurple,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Selector de módulo
            Container(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
              color: WorkflowTheme.surface,
              child: ModuleSelector(
                selectedModule: _moduloSeleccionado,
                onModuleChanged: _onModuloChanged,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return isMobile
                      ? _buildMobileLayout()
                      : _buildDesktopLayout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel izquierdo - Estados
          Expanded(
            flex: 25,
            child: StatesPanel(
              estados: _estados,
              isLoading: _isLoadingEstados,
              error: _errorEstados,
              estadosBase: _estadosBase,
              modulo: _moduloSeleccionado.key,
              canCreate: _canCreate,
              canEdit: _canEdit,
              canDelete: _canDelete,
              onCreateState: _crearEstado,
              onEditState: _mostrarDialogoEdicion,
              onDeleteState: _eliminarEstado,
            ),
          ),

          const SizedBox(width: WorkflowDesignConstants.spacing),

          // Panel central - Diagrama
          Expanded(
            flex: 55,
            child: DiagramPanel(
              estados: _estados,
              transiciones: _transiciones,
              modoEdicion: _modoEdicion,
              onModoEdicionChanged: (value) {
                setState(() => _modoEdicion = value);
              },
              isLoading: _isLoadingEstados || _isLoadingTransiciones,
              error: _errorEstados ?? _errorTransiciones,
              diagramWidget: _buildDiagramWidget(),
              onAutoLayout: () {
                // Forzar recalculo de layout
                _initializeNodePositions();
                // Auto-centrar después de reorganizar
                Future.delayed(const Duration(milliseconds: 600), () {
                  _centerView();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Layout reorganizado y centrado automáticamente',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              onZoomIn: () {
                final current = _currentZoom;
                final newZoom = (current * 1.2).clamp(0.1, 4.0);
                final center = _diagramTransform.value.getTranslation();
                _diagramTransform.value =
                    Matrix4.identity()
                      ..translate(center.x, center.y)
                      ..scale(newZoom);
              },
              onZoomOut: () {
                final current = _currentZoom;
                final newZoom = (current / 1.2).clamp(0.1, 4.0);
                final center = _diagramTransform.value.getTranslation();
                _diagramTransform.value =
                    Matrix4.identity()
                      ..translate(center.x, center.y)
                      ..scale(newZoom);
              },
              onResetZoom: () {
                _centerView(); // Centrar vista en todos los nodos
              },
              currentZoom: _currentZoom,
            ),
          ),

          const SizedBox(width: WorkflowDesignConstants.spacing),

          // Panel derecho - Transiciones
          Expanded(
            flex: 20,
            child: TransitionsPanel(
              modulo: _moduloSeleccionado.key,
              transiciones: _transiciones,
              estados: _estados,
              isLoading: _isLoadingTransiciones,
              error: _errorTransiciones,
              onDeleteTransition: _eliminarTransicion,
              onEditTransition: _editarTransicion,
              canDelete: _canDelete,
              canEdit: _canEdit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    // TODO: Implementar layout mobile con tabs
    return const Center(child: Text('Vista móvil en desarrollo'));
  }

  Widget? _buildDiagramWidget() {
    if (_estados.isEmpty) return null;

    const canvasWidth = 5000.0; // Canvas grande para navegación infinita
    const canvasHeight = 5000.0;

    return InteractiveViewer(
      transformationController: _diagramTransform,
      boundaryMargin: const EdgeInsets.all(500),
      minScale: 0.1,
      maxScale: 4.0,
      constrained: false, // Lienzo infinito
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: Stack(
          children: [
            // ============================================
            // CAPA 1: FONDO - Rejilla (debe estar al fondo)
            // ============================================
            CustomPaint(
              size: const Size(canvasWidth, canvasHeight),
              painter: GridBackgroundPainter(
                spacing: 50,
                gridColor: const Color(0xFFE5E7EB),
                showDots: false,
              ),
            ),

            // ============================================
            // CAPA 2: CONEXIONES - Líneas de Bézier
            // ============================================
            CustomPaint(
              size: const Size(canvasWidth, canvasHeight),
              painter: ConnectionsPainter(
                transiciones: _transiciones,
                nodePositions: _nodePositions,
                selectedTransitionId: _selectedTransitionId?.toString(),
                nodeWidth: 180,
                nodeHeight: 80,
              ),
            ),

            // Línea temporal durante creación de conexión
            if (_modoEdicion &&
                _diagramOrigenSeleccionado != null &&
                _dragScenePos != null)
              CustomPaint(
                size: const Size(canvasWidth, canvasHeight),
                painter: TemporaryConnectionPainter(
                  startPosition:
                      _nodePositions[_diagramOrigenSeleccionado.toString()],
                  endPosition: _dragScenePos,
                ),
              ),

            // ============================================
            // CAPA 3: NODOS - Estados interactivos (CAPA SUPERIOR para hit testing)
            // ============================================
            ..._estados.map((estado) {
              final id = estado['id'].toString();
              final position = _nodePositions[id];

              if (position == null) return const SizedBox.shrink();

              final nombre = estado['nombre_estado'] ?? 'Sin nombre';
              final colorHex = estado['color'] ?? '#808080';
              final color = _parseColor(colorHex);

              final orden = int.tryParse(estado['orden']?.toString() ?? '0');
              final isInitial =
                  orden == 0 || nombre.toUpperCase().contains('ABIERTO');
              final isFinal =
                  (int.tryParse(estado['es_final']?.toString() ?? '0') ?? 0) ==
                      1 ||
                  nombre.toUpperCase().contains('CERRADO') ||
                  nombre.toUpperCase().contains('FINALIZADO');
              final requiresSignature =
                  (int.tryParse(estado['requiere_firma']?.toString() ?? '0') ??
                      0) ==
                  1;

              return DraggableWorkflowNode(
                key: ValueKey(id),
                id: id,
                name: nombre,
                color: color,
                position: position,
                modulo: _moduloSeleccionado.key,
                isInitial: isInitial,
                isFinal: isFinal,
                requiresSignature: requiresSignature,
                isDraggable: _modoEdicion && _canEdit,
                onPositionChanged: _updateNodePosition,
                onTap: () => _handleNodeTap(id),
                onEdit:
                    _canEdit
                        ? () => _mostrarDialogoEdicion(
                          int.tryParse(id) ?? 0,
                          nombre,
                        )
                        : null,
                onDelete:
                    _canDelete
                        ? () => _eliminarEstado(int.tryParse(id) ?? 0)
                        : null,
                isSelected: _diagramOrigenSeleccionado?.toString() == id,
              );
            }),

            // ============================================
            // CAPA 4: MINI-MAPA - NO debe bloquear clics
            // ============================================
            Positioned(
              left: 16,
              bottom: 16,
              child: IgnorePointer(
                ignoring: false, // El mini-mapa SÍ recibe clics
                child: SizedBox(
                  // Contenedor con tamaño fijo para evitar bloquear todo
                  width: 180,
                  height: 120,
                  child: MiniMapWidget(
                    canvasSize: const Size(canvasWidth, canvasHeight),
                    estados: _estados,
                    nodePositions: _nodePositions,
                    currentTransform: _diagramTransform.value,
                    onNavigate: _navigateToPosition,
                    width: 180,
                    height: 120,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maneja el tap en un nodo (para selección o creación de conexión)
  void _handleNodeTap(String id) {
    if (!_modoEdicion) {
      // Modo normal: solo seleccionar
      _selectNode(id);
      return;
    }

    // Modo edición: crear conexión
    final idInt = int.tryParse(id);
    if (idInt == null) return;

    if (_diagramOrigenSeleccionado == null) {
      // Primer clic: seleccionar origen
      setState(() {
        _diagramOrigenSeleccionado = idInt;
      });
    } else if (_diagramOrigenSeleccionado == idInt) {
      // Clic en el mismo nodo: cancelar
      setState(() {
        _diagramOrigenSeleccionado = null;
        _dragScenePos = null;
      });
    } else {
      // Segundo clic: crear transición
      _crearTransicionDiagrama(_diagramOrigenSeleccionado!, idInt);
      setState(() {
        _diagramOrigenSeleccionado = null;
        _dragScenePos = null;
      });
    }
  }

  /// Actualiza la posición de un nodo cuando se arrastra
  void _updateNodePosition(String id, Offset newPosition) {
    setState(() {
      _nodePositions[id] = newPosition;
    });
    // TODO: Guardar en backend si se implementa persistencia
  }

  /// Selecciona un nodo
  void _selectNode(String id) {
    setState(() {
      final idInt = int.tryParse(id);
      _diagramOrigenSeleccionado = idInt;
    });
  }

  /// Parsea un color hexadecimal
  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  /// Navega a una posición específica del canvas desde el mini-mapa
  /// Centra la vista en todos los nodos o en una posición específica
  void _centerView({Offset? targetPosition}) {
    if (_nodePositions.isEmpty) return;

    final context = this.context;
    if (!context.mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Viewport real (Panel Central)
    // En Desktop es aproximadamente el 55% del ancho menos márgenes
    final isMobile = renderBox.size.width < 600;
    final viewportWidth = isMobile ? renderBox.size.width : renderBox.size.width * 0.55;
    final viewportHeight = renderBox.size.height - 200; // Restar AppBar y Header

    Offset center;
    double targetScale = 1.0;

    if (targetPosition != null) {
      // Centrar en posición específica (desde mini-mapa)
      center = targetPosition;
      targetScale = _currentZoom; // Mantener zoom actual
    } else {
      // Calcular bounding box de todos los nodos
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = double.negativeInfinity;
      double maxY = double.negativeInfinity;

      for (final pos in _nodePositions.values) {
        if (pos.dx < minX) minX = pos.dx;
        if (pos.dy < minY) minY = pos.dy;
        if (pos.dx > maxX) maxX = pos.dx;
        if (pos.dy > maxY) maxY = pos.dy;
      }

      // Centro del bounding box
      center = Offset((minX + maxX) / 2, (minY + maxY) / 2);

      // Calcular escala para ajustar
      final contentWidth = maxX - minX + 500; // Margen generoso
      final contentHeight = maxY - minY + 400;

      final scaleX = viewportWidth / contentWidth;
      final scaleY = viewportHeight / contentHeight;
      targetScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.2, 1.5);
    }

    // Calcular traducción para colocar el 'center' en el centro del viewport
    final tx = (viewportWidth / 2) - (center.dx * targetScale);
    final ty = (viewportHeight / 2) - (center.dy * targetScale);

    final translation = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(targetScale);

    setState(() {
      _diagramTransform.value = translation;
      _currentZoom = targetScale;
    });
  }

  /// Navega a una posición específica (desde mini-mapa)
  void _navigateToPosition(Offset position) {
    _centerView(targetPosition: position);
  }
}
