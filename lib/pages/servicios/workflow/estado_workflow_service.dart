import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../../../core/enums/modulo_enum.dart';
import '../services/estados_service.dart';
import 'estado_workflow_models.dart';

/// Servicio no intrusivo para validar y consultar transiciones de estado.
/// Si no hay configuración, permite todas las transiciones (compatibilidad).
/// ✅ NUEVO: Soporta múltiples módulos independientes
class EstadoWorkflowService {
  static final EstadoWorkflowService _instance = EstadoWorkflowService._();
  factory EstadoWorkflowService() => _instance;
  EstadoWorkflowService._();

  // ✅ NUEVO: Configuraciones por módulo
  final Map<ModuloEnum, WorkflowDef?> _configs = {};
  final Map<ModuloEnum, Map<String, Set<String>>> _maps = {};
  final Map<ModuloEnum, bool> _loadingStates = {};

  // ✅ DEPRECATED: Mantener compatibilidad con código existente
  WorkflowDef? get _config => _configs[ModuloEnum.servicios];
  Map<String, Set<String>> get _map => _maps[ModuloEnum.servicios] ?? {};
  bool get _loading => _loadingStates[ModuloEnum.servicios] ?? false;

  /// Asegura que la configuración esté cargada una vez.
  /// Preferencia: backend → asset JSON (fallback).
  /// ✅ NUEVO: Soporta carga por módulo
  Future<void> ensureLoaded({
    ModuloEnum modulo = ModuloEnum.servicios,
    String? assetPath,
    bool force = false,
  }) async {
    // Determinar asset path por módulo si no se establece
    assetPath ??= 'assets/workflows/${modulo.key}_estados.json';

    if (!force &&
        (_configs[modulo] != null || (_loadingStates[modulo] ?? false))) {
      return;
    }
    _loadingStates[modulo] = true;

    try {
      // 1) Intentar cargar desde backend
      final backendLoaded = await _tryLoadFromBackend(modulo: modulo);
      if (!backendLoaded) {
        // 2) Fallback: sólo para módulos distintos de Equipos.
        //    Para Equipos evitamos cargar assets para mantener backend-only y código más liviano.
        if (modulo != ModuloEnum.equipos) {
          try {
            final source = await rootBundle.loadString(assetPath);
            _configs[modulo] = WorkflowDef.fromJsonString(source);
            _rebuildMap(modulo: modulo);
          } catch (_) {
            // Asset no existe, usar configuración por defecto
            _configs[modulo] = const WorkflowDef(
              allowUnconfiguredTransitions: true,
              estados: [],
              transiciones: [],
            );
          }
        } else {
          // Equipos: sin fallback a assets, usar configuración permisiva por defecto
          _configs[modulo] = const WorkflowDef(
            allowUnconfiguredTransitions: true,
            estados: [],
            transiciones: [],
          );
        }
      }
    } catch (_) {
      // Sin config: compatibilidad total
      _configs[modulo] = const WorkflowDef(
        allowUnconfiguredTransitions: true,
        estados: [],
        transiciones: [],
      );
    } finally {
      _loadingStates[modulo] = false;
    }
  }

  /// Fuerza recarga desde backend, con fallback a mantener config actual si falla.
  /// ✅ NUEVO: Soporta recarga por módulo
  Future<void> reload({ModuloEnum modulo = ModuloEnum.servicios}) async {
    if (_loadingStates[modulo] ?? false) return;
    _loadingStates[modulo] = true;
    try {
      final ok = await _tryLoadFromBackend(modulo: modulo);
      if (!ok) {
        // Si falla, mantener configuración existente (no tocar _configs[modulo])
      }
    } finally {
      _loadingStates[modulo] = false;
    }
  }

  /// Carga estados y transiciones desde los endpoints del backend y construye el mapa.
  /// Devuelve true si se cargó correctamente.
  /// ✅ NUEVO: Soporta carga por módulo específico
  Future<bool> _tryLoadFromBackend({
    ModuloEnum modulo = ModuloEnum.servicios,
  }) async {
    try {
      // Estados filtrados por módulo
      final estadosResp = await http.get(
        Uri.parse(
          '${EstadosService.baseUrl}/workflow/listar_estados.php?modulo=${modulo.key}',
        ),
      );
      if (estadosResp.statusCode != 200) return false;

      final estadosData = _safeDecode(estadosResp.body.trim());
      List<dynamic> estadosList;
      if (estadosData is List) {
        estadosList = estadosData;
      } else if (estadosData is Map<String, dynamic> &&
          estadosData['estados'] is List) {
        estadosList = estadosData['estados'] as List<dynamic>;
      } else if (estadosData is Map<String, dynamic> &&
          estadosData['data'] is List) {
        estadosList = estadosData['data'] as List<dynamic>;
      } else {
        return false;
      }

      if (estadosList.isEmpty) return false;

      // Mapear id → nombre y color
      final Map<int, String> idToNombre = {};
      final Map<int, String> idToEstadoBase = {}; // âœ… NUEVO
      final List<EstadoDef> estadosDef = [];

      for (final e in estadosList) {
        final m = e as Map<String, dynamic>;
        final id = int.tryParse(m['id']?.toString() ?? '');
        final nombre =
            m['nombre_estado']?.toString() ?? m['nombre']?.toString() ?? '';
        final color = m['color']?.toString() ?? '#808080';

        if (id != null && nombre.isNotEmpty) {
          idToNombre[id] = nombre;
          idToEstadoBase[id] = m['estado_base_codigo']?.toString() ?? 'ABIERTO'; // âœ… NUEVO
          estadosDef.add(
            EstadoDef(id: id.toString(), nombre: nombre, colorHex: color),
          );
        }
      }

      // Transiciones filtradas por módulo
      final transResp = await http.get(
        Uri.parse(
          '${EstadosService.baseUrl}/workflow/listar_transiciones.php?modulo=${modulo.key}',
        ),
      );
      if (transResp.statusCode != 200) return false;
      final raw = transResp.body.trim();
      final dynamic data = _safeDecode(raw);
      List<dynamic> transList;
      if (data is List) {
        transList = data;
      } else if (data is Map<String, dynamic> && data['transiciones'] is List) {
        transList = data['transiciones'] as List<dynamic>;
      } else if (data is Map<String, dynamic> && data['data'] is List) {
        transList = data['data'] as List<dynamic>;
      } else {
        return false;
      }

      // Construir WorkflowDef usando nombres para compatibilidad actual.
      // Deduplicamos por (origenId, destinoId) — clave numérica inmutable —
      // para evitar botones duplicados cuando un estado fue renombrado y el
      // caché del singleton guardaba el nombre anterior.
      final transiciones = <WorkflowTransicionDef>[];
      final seenPairs = <String>{};
      for (final t in transList) {
        final m = t as Map<String, dynamic>;
        final origenId = int.tryParse(m['estado_origen_id']?.toString() ?? '');
        final destinoId = int.tryParse(
          m['estado_destino_id']?.toString() ?? '',
        );
        if (origenId == null || destinoId == null) continue;
        // Deduplicar: si ya existe esta combinación origen→destino, omitir
        final pairKey = '$origenId→$destinoId';
        if (!seenPairs.add(pairKey)) continue;
        final fromNombre = idToNombre[origenId];
        final toNombre = idToNombre[destinoId];
        final nombre = m['nombre']?.toString();
        final triggerCode = m['trigger_code']?.toString();

        if (fromNombre == null || toNombre == null) continue;
        transiciones.add(
          WorkflowTransicionDef(
            from: fromNombre,
            to: toNombre,
            toId: destinoId,
            toEstadoBase: idToEstadoBase[destinoId], // âœ… NUEVO
            nombre: nombre,
            triggerCode: triggerCode,
          ),
        );
      }

      _configs[modulo] = WorkflowDef(
        allowUnconfiguredTransitions: true, // política por defecto
        estados: estadosDef,
        transiciones: transiciones,
      );
      _rebuildMap(modulo: modulo);
      return true;
    } catch (_) {
      return false;
    }
  }

  dynamic _safeDecode(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      // Algunos endpoints pueden tener ruido antes/después del JSON
      final start = source.indexOf('{');
      if (start > 0) {
        final s = source.substring(start);
        try {
          return jsonDecode(s);
        } catch (_) {}
      }
      return {};
    }
  }

  /// ✅ NUEVO: Reconstruye el mapa para un módulo específico
  void _rebuildMap({ModuloEnum modulo = ModuloEnum.servicios}) {
    _maps[modulo] = {};
    final config = _configs[modulo];
    if (config == null) return;
    for (final t in config.transiciones) {
      // Map normalized from -> set of to (trimmed and uppercase)
      _maps[modulo]!
          .putIfAbsent(t.from.trim().toUpperCase(), () => <String>{})
          .add(t.to.trim());
    }
  }

  /// Devuelve true si la transición está permitida por la configuración
  /// o si la política es permisiva cuando no está definida.
  /// ✅ NUEVO: Soporta validación por módulo
  bool canTransition(
    String from,
    String to, {
    ModuloEnum modulo = ModuloEnum.servicios,
  }) {
    final map = _maps[modulo] ?? {};
    final config = _configs[modulo];

    if (map.isEmpty) {
      return config?.allowUnconfiguredTransitions ?? true;
    }
    // Lookup case-insensitive and trimmed
    final allowed = map[from.trim().toUpperCase()];
    // Check if target is in allowed set (case-insensitive check for robustness)
    if (allowed == null) return config?.allowUnconfiguredTransitions ?? true;

    return allowed.any(
      (s) => s.trim().toUpperCase() == to.trim().toUpperCase(),
    );
  }

  /// Lista de estados siguientes posibles desde `from`.
  /// ✅ NUEVO: Soporta consulta por módulo
  UnmodifiableListView<String> nextStates(
    String from, {
    ModuloEnum modulo = ModuloEnum.servicios,
  }) {
    final map = _maps[modulo] ?? {};
    // Lookup case-insensitive and trimmed
    final allowed = map[from.trim().toUpperCase()] ?? const <String>{};
    return UnmodifiableListView<String>(allowed.toList());
  }

  /// ✅ NUEVO: Obtener transiciones completas disponibles desde un estado
  List<WorkflowTransicionDef> getAvailableTransitions(
    String fromStateName, {
    ModuloEnum modulo = ModuloEnum.servicios,
  }) {
    final config = _configs[modulo];
    if (config == null) return [];

    return config.transiciones
        .where(
          (t) =>
              t.from.trim().toUpperCase() == fromStateName.trim().toUpperCase(),
        )
        .toList();
  }

  /// ✅ NUEVO: Obtener configuración por módulo
  WorkflowDef? getConfig({ModuloEnum modulo = ModuloEnum.servicios}) =>
      _configs[modulo];

  /// ✅ DEPRECATED: Mantener compatibilidad
  WorkflowDef? get config => _configs[ModuloEnum.servicios];
}
