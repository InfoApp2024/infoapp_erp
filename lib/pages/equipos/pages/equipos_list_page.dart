import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:infoapp/core/utils/download_utils.dart' as dl;

import 'package:infoapp/pages/equipos/models/equipo_model.dart';
import 'package:infoapp/pages/equipos/services/equipos_api_service.dart';
import 'package:infoapp/pages/equipos/controllers/equipos_controller.dart'
    as ec;
import 'package:infoapp/pages/equipos/pages/equipo_form_page.dart';
import 'package:infoapp/pages/equipos/pages/equipo_detail_page.dart';
import 'package:infoapp/pages/equipos/widgets/equipos_import_export_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/config/module_column_config_modal.dart';
import 'package:infoapp/core/utils/module_utils.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/models/campo_adicional_model.dart';
import 'package:infoapp/pages/servicios/services/campos_adicionales_api_service.dart';
import 'package:infoapp/pages/servicios/services/download_service.dart';

class EquiposListPage extends StatefulWidget {
  const EquiposListPage({super.key});

  @override
  State<EquiposListPage> createState() => _EquiposListPageState();
}

class _EquiposListPageState extends State<EquiposListPage> {
  // Estado principal
  List<EquipoModel> _equipos = [];
  List<EquipoModel> _equiposFiltrados = [];
  bool _isLoading = false;
  String _filtroTexto = '';
  int? _filtroEstadoId;
  List<EstadoModel> _estados = [];

  // Paginación
  int _paginaActual = 1;
  int _totalPaginas = 1;
  int _totalRegistros = 0;
  int _limite = 20;

  // Ordenamiento
  int? _sortColumnIndex;
  bool _sortAscending = false; // Por defecto descendente, como en Servicios
  String? _sortColumnId;

  // Persistencia
  static const String _prefsColsKey = 'equipos_cols_visible';
  static const String _prefsColsKeyList = 'equipos_columnas_visibles';
  // Migración de preferencia de orden: nueva clave para default descendente
  static const String _prefsSortKey = 'equipos_sort_v2';
  static const String _prefsPageKey = 'equipos_pagina_actual';
  static const String _prefsPageSizeKey = 'tabla_prefs.page_size';

  // Configuración de columnas visibles
  late final List<_ColDef> _columnas = [
    _ColDef(
      id: 'numero',
      titulo: 'N°',
      requerida: true,
      visible: true,
      ordenable: true,
      width: 80,
    ),
    // Acciones solo muestra 2 íconos, reducir ancho
    _ColDef(
      id: 'acciones',
      titulo: 'Acciones',
      requerida: true,
      visible: true,
      ordenable: false,
      width: 80,
    ),
    // Mover Estado inmediatamente después de Acciones, como en Servicios
    _ColDef(
      id: 'estado',
      titulo: 'Estado',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 200,
    ),
    _ColDef(
      id: 'empresa',
      titulo: 'Empresa',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 220,
    ),
    _ColDef(
      id: 'equipo',
      titulo: 'Equipo',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 220,
    ),
    _ColDef(
      id: 'codigo',
      titulo: 'Código',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 140,
    ),
    _ColDef(
      id: 'marca',
      titulo: 'Marca',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 160,
    ),
    _ColDef(
      id: 'modelo',
      titulo: 'Modelo',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 160,
    ),
    _ColDef(
      id: 'ciudad',
      titulo: 'Ciudad',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 160,
    ),
    _ColDef(
      id: 'placa',
      titulo: 'Placa',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 140,
    ),
    _ColDef(
      id: 'planta',
      titulo: 'Planta',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 160,
    ),
    _ColDef(
      id: 'linea',
      titulo: 'Línea',
      requerida: false,
      visible: true,
      ordenable: true,
      width: 180,
    ),
  ];

  // Columnas dinámicas de campos adicionales
  List<_ColDef> _columnasAdicionales = [];
  // Campos adicionales únicos y valores por equipo
  List<CampoAdicionalModel> _camposAdicionalesUnicos = [];
  final Map<int, List<CampoAdicionalModel>> _valoresCamposAdicionales = {};
  bool _isLoadingCamposAdicionales = false;

  // UI
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _hScrollCtrl = ScrollController();
  final ScrollController _vScrollCtrl = ScrollController();
  final Set<int> _seleccionadosIds = <int>{};

  // Helper: estado con punto de color y texto (igual a Servicios)
  Widget _buildEstadoChip(String? nombre, String? colorHex, {int? estadoId}) {
    String n = (nombre ?? '').trim();
    String? cHex = colorHex;
    // Priorizar estadoId para nombre/color si está disponible
    if (estadoId != null) {
      try {
        final est = _estados.firstWhere((e) => e.id == estadoId);
        n = est.nombre;
        cHex = est.color;
      } catch (_) {
        // si no se encuentra, usar nombre/color originales
      }
    }
    if (n.isEmpty) return const SizedBox.shrink();

    Color parseColor(String? hex) {
      final h = (hex ?? cHex ?? '').replaceAll('#', '');
      if (h.length == 6) {
        return Color(int.parse('FF$h', radix: 16));
      }
      switch (n.toLowerCase()) {
        case 'activo':
          return const Color(0xFF4CAF50);
        case 'en mantenimiento':
          return const Color(0xFFFB8C00);
        case 'en préstamo':
          return const Color(0xFF64B5F6);
        case 'inactivo':
          return const Color(0xFF9E9E9E);
        case 'de baja':
          return const Color(0xFFE57373);
        default:
          return const Color(0xFF607D8B);
      }
    }

    final color = parseColor(colorHex);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.surface,
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            n.toUpperCase(),
            style: const TextStyle(fontSize: 10),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionInicial().then((_) async {
      await _cargarEstados();
      await _cargarEquipos();
    });
  }

  Future<void> _cargarConfiguracionInicial() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar paginación persistida SOLO al inicio
      final savedPage = prefs.getInt(_prefsPageKey);
      if (savedPage != null && savedPage > 0) {
        _paginaActual = savedPage;
      }
      final savedSize = prefs.getInt(_prefsPageSizeKey);
      if (savedSize != null && savedSize > 0) {
        _limite = savedSize;
      }

      // Cargar visualización
      await _cargarPrefs();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _cargarPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Nuevo esquema: lista de ids visibles (configurables), clave modular
      final modularKey = ModuleUtils.prefsKeyColumnasVisibles('Equipos');
      List<String>? colsList = prefs.getStringList(modularKey);
      // Fallback a clave antigua si aún existe
      colsList ??= prefs.getStringList(_prefsColsKeyList);
      if (colsList != null && colsList.isNotEmpty) {
        _aplicarColumnasVisiblesDesdeIds(colsList);
      } else {
        final colsJson = prefs.getString(_prefsColsKey);
        if (colsJson != null && colsJson.isNotEmpty) {
          final Map<String, dynamic> map = json.decode(colsJson);
          for (final c in _columnas) {
            if (map.containsKey(c.id)) {
              c.visible = (map[c.id] as bool? ?? c.visible);
            }
          }
        }
      }

      final sortJson = prefs.getString(_prefsSortKey);
      if (sortJson != null && sortJson.isNotEmpty) {
        final Map<String, dynamic> s = json.decode(sortJson);
        _sortColumnId = s['id'] as String?;
        _sortAscending = s['asc'] as bool? ?? _sortAscending;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _guardarPrefsColumnas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Guardar como lista de ids visibles (excluyendo obligatorias)
      final visiblesIds = <String>[];
      for (final c in [..._columnas, ..._columnasAdicionales]) {
        if (!c.requerida && c.visible) visiblesIds.add(c.id);
      }
      await prefs.setStringList(
        ModuleUtils.prefsKeyColumnasVisibles('Equipos'),
        visiblesIds,
      );
    } catch (_) {}
  }

  Future<void> _guardarPrefsSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsSortKey,
        json.encode({'id': _sortColumnId, 'asc': _sortAscending}),
      );
    } catch (_) {}
  }

  Future<void> _cargarEstados() async {
    try {
      // Solo estados del módulo "equipo"
      _estados = await ServiciosApiService.listarEstados(modulo: 'equipo');
      _estados.sort((a, b) => a.id.compareTo(b.id));
    } catch (_) {
      _estados = [];
    }
    if (mounted) setState(() {});
  }

  /// ✅ OPTIMIZADO: Cargar equipos con datos en paralelo
  Future<void> _cargarEquipos({int? pagina}) async {
    setState(() => _isLoading = true);
    try {
      // ✅ PASO 1: Cargar equipos primero (los datos ya vienen merged del servidor)
      await _cargarEquiposInterno(pagina: pagina);

      // ✅ PASO 2: Cargar estados si no están presentes
      if (_estados.isEmpty) await _cargarEstados();

      // Nota: El batch ya no es necesario llamarlo aquí porque listar_equipos.php
      // ya devuelve campos_adicionales integrados en la respuesta principal.
    } catch (e) {
      _equipos = [];
      _equiposFiltrados = [];
      _totalRegistros = 0;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ✅ NUEVO: Método interno para cargar solo los datos de equipos
  Future<void> _cargarEquiposInterno({int? pagina}) async {
    final r = await EquiposApiService.listarEquiposPaginado(
      pagina: pagina ?? _paginaActual,
      limite: _limite,
      buscar: _filtroTexto.isNotEmpty ? _filtroTexto : null,
      estadoId: _filtroEstadoId,
      // Solicitar al backend orden por id DESC para que la página 1
      // traiga los más recientes; el cliente puede reordenar otras columnas.
      sortBy: 'id',
      sortOrder: (_sortColumnId == 'numero' && _sortAscending) ? 'ASC' : 'DESC',
    );
    final equiposNuevos = (r['equipos'] as List<EquipoModel>);
    _totalRegistros = (r['total'] as int? ?? equiposNuevos.length);
    _paginaActual = (r['pagina'] as int? ?? _paginaActual);
    _totalPaginas = (r['totalPaginas'] as int? ?? 1);

    // ✅ ACTUALIZAR UI: Sincronizar listas y estado atómicamente
    if (mounted) {
      setState(() {
        _equipos = equiposNuevos;
        _equiposFiltrados = List.from(
          equiposNuevos,
        ); // Sincronizado 100% con servidor
        _isLoading = false;
      });
    }

    // Aplicar orden persistido si existe
    if (_sortColumnId != null) {
      _ordenarPor(_sortColumnId!, _sortAscending);
    } else {
      // Orden por defecto: ID descendente (más recientes primero)
      _ordenarPor('numero', false);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsPageKey, _paginaActual);
    } catch (_) {}

    final camposMerged = r['campos_adicionales'] as Map<int, List<dynamic>>?;

    // 🆕 PROCESAMIENTO DE DATOS MERGEADOS
    if (camposMerged != null && camposMerged.isNotEmpty) {
      // Limpiar
      _valoresCamposAdicionales.clear();
      final Set<int> unicosIds = {};
      final List<CampoAdicionalModel> listaUnicos = [];

      // Procesar mapa
      camposMerged.forEach((sid, listaRaw) {
        final listaModel =
            listaRaw.map((json) => CampoAdicionalModel.fromJson(json)).toList();

        _valoresCamposAdicionales[sid] = listaModel;

        // Extraer definiciones únicas
        for (final c in listaModel) {
          if (!unicosIds.contains(c.id)) {
            unicosIds.add(c.id);
            listaUnicos.add(c);
          }
        }
      });

      // Actualizar UI de columnas si hay nuevos campos
      if (listaUnicos.isNotEmpty) {
        setState(() {
          _camposAdicionalesUnicos = listaUnicos;
          // Reconstruir columnas adicionales
          _columnasAdicionales =
              _camposAdicionalesUnicos
                  .map(
                    (c) => _ColDef(
                      id: 'campo_${c.id}',
                      titulo: c.nombreCampo,
                      requerida: false,
                      visible: false,
                      ordenable: false,
                      width: _getWidthForFieldType(c.tipoCampo),
                    ),
                  )
                  .toList();
        });
      }
    }
  }

  Future<void> _cargarCamposAdicionalesBatch() async {
    if (_equipos.isEmpty) return;
    setState(() => _isLoadingCamposAdicionales = true);
    try {
      // ✅ NUEVO: Obtener lista de campos que realmente existen en la base de datos
      final camposDisponibles =
          await CamposAdicionalesApiService.obtenerCamposDisponibles(
            modulo: 'Equipos',
          );
      final Set<int> idsValidos = camposDisponibles.map((c) => c.id).toSet();

      final ids =
          _equipos.where((e) => e.id != null).map((e) => e.id!).toList();
      if (ids.isEmpty) return;
      final batch = await CamposAdicionalesApiService.obtenerCamposBatch(
        servicioIds: ids,
        modulo: 'Equipos',
      );
      _valoresCamposAdicionales.clear();
      batch.forEach((sid, valores) {
        final filtrados =
            valores
                .where(
                  (c) => ModuleUtils.esModulo(
                    c.modulo,
                    'Equipos',
                    // Aceptar vacío para valores: backend puede omitir módulo
                    aceptarVacioComoDestino: true,
                  ),
                )
                .toList();
        _valoresCamposAdicionales[sid] = filtrados;
      });

      // Unificar campos únicos
      final Set<int> unicos = {};
      final List<CampoAdicionalModel> lista = [];
      batch.forEach((sid, valores) {
        for (final c in valores.where(
          (c) => ModuleUtils.esModulo(
            c.modulo,
            'Equipos',
            aceptarVacioComoDestino: false,
          ),
        )) {
          if (!unicos.contains(c.id)) {
            unicos.add(c.id);
            lista.add(c);
          }
        }
      });

      // ✅ NUEVO: Filtrar solo campos que existen en la base de datos
      final List<CampoAdicionalModel> camposFiltrados =
          lista.where((c) => idsValidos.contains(c.id)).toList();

      // 🛟 Fallback: si el batch no trae campos, usar metadatos por estado (rápido)
      List<CampoAdicionalModel> resultadoFinal = camposFiltrados;
      if (resultadoFinal.isEmpty) {
        try {
          // Fallback de campos adicionales [Equipos]: usando metadatos por estado
          final estadosUnicos =
              _equipos
                  .map((e) => e.estadoId)
                  .where((e) => e != null)
                  .cast<int>()
                  .toSet()
                  .toList();
          final List<CampoAdicionalModel> desdeMetadatos = [];
          for (final estadoId in estadosUnicos) {
            try {
              // Intento con módulo esperado por backend: 'equipo' (singular, minúsculas)
              var camposEstado =
                  await ServiciosApiService.obtenerCamposPorEstadoRapido(
                    estadoId: estadoId,
                    modulo: 'equipo',
                  );
              // Si aún viene vacío, probar variante 'Equipos'
              if (camposEstado.isEmpty) {
                camposEstado =
                    await ServiciosApiService.obtenerCamposPorEstadoRapido(
                      estadoId: estadoId,
                      modulo: 'Equipos',
                    );
              }
              desdeMetadatos.addAll(camposEstado);
            } catch (e) {
              // Error metadatos estado $estadoId (Equipos)
            }
          }

          // Unificar por ID y filtrar por módulo Equipos
          final Map<int, CampoAdicionalModel> porId = {};
          for (final c in desdeMetadatos) {
            if (ModuleUtils.esModulo(
                  c.modulo,
                  'Equipos',
                  aceptarVacioComoDestino: false,
                ) &&
                idsValidos.contains(c.id)) {
              // ✅ También filtrar en fallback
              porId[c.id] = c;
            }
          }
          resultadoFinal = porId.values.toList();
        } catch (e) {
          // Error en fallback de metadatos (Equipos)
        }
      }

      _camposAdicionalesUnicos = resultadoFinal;
      try {
        // Campos adicionales únicos cargados [Equipos] (final)
      } catch (_) {}

      // Construir columnas adicionales y aplicar visibilidad desde prefs
      _columnasAdicionales =
          _camposAdicionalesUnicos
              .map(
                (c) => _ColDef(
                  id: 'campo_${c.id}',
                  titulo: c.nombreCampo,
                  requerida: false,
                  visible: false,
                  ordenable: false,
                  width: _getWidthForFieldType(c.tipoCampo),
                ),
              )
              .toList();

      // 🛟 Fallback de valores: si el batch no trajo valores, cargar por equipo
      try {
        if (_valoresCamposAdicionales.isEmpty &&
            _camposAdicionalesUnicos.isNotEmpty) {
          // Fallback valores [Equipos]: cargando por equipo en paralelo (hasta 50)
          final idsPermitidos =
              _camposAdicionalesUnicos.map((c) => c.id).toSet();
          final equiposParaCargar =
              _equipos.where((e) => e.id != null).take(50).toList();

          // Usar Future.wait para realizar peticiones en paralelo
          await Future.wait(
            equiposParaCargar.map((eq) async {
              final sid = eq.id!;
              try {
                var campos =
                    await CamposAdicionalesApiService.obtenerCamposConValores(
                      servicioId: sid,
                      modulo: 'Equipos',
                    );
                // Filtrar por módulo Equipos y por ids visibles/configurados
                campos =
                    campos
                        .where(
                          (c) =>
                              ModuleUtils.esModulo(
                                c.modulo,
                                'Equipos',
                                // Aceptar vacío para valores: backend puede omitir módulo
                                aceptarVacioComoDestino: true,
                              ) &&
                              idsPermitidos.contains(c.id),
                        )
                        .toList();
                if (campos.isNotEmpty) {
                  // Usar setState o variable local sincronizada si fuera crítico,
                  // pero aquí _valoresCamposAdicionales no está en setState hasta el final.
                  // Dart es single threaded, el acceso al mapa es seguro entre await.
                  _valoresCamposAdicionales[sid] = campos;
                }
              } catch (e) {
                // Error cargando valores por equipo $sid
              }
            }),
          );
          // Fallback valores [Equipos] completado
        }
      } catch (e) {
        // Error general en fallback de valores [Equipos]
      }

      // Aplicar configuración guardada si existe
      try {
        final prefs = await SharedPreferences.getInstance();
        final colsList = prefs.getStringList(_prefsColsKeyList);
        if (colsList != null && colsList.isNotEmpty) {
          _aplicarColumnasVisiblesDesdeIds(colsList);
        }
      } catch (_) {}
    } catch (_) {
      _camposAdicionalesUnicos = [];
      _columnasAdicionales = [];
    } finally {
      if (mounted) setState(() => _isLoadingCamposAdicionales = false);
    }
  }

  double _getWidthForFieldType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'texto':
      case 'párrafo':
        return 200;
      case 'link':
        return 220;
      case 'entero':
      case 'decimal':
      case 'moneda':
        return 120;
      case 'fecha':
        return 140;
      case 'imagen':
      case 'archivo':
        return 160;
      default:
        return 180;
    }
  }


  void _aplicarColumnasVisiblesDesdeIds(List<String> ids) {
    // Obligatorias siempre visibles
    for (final c in _columnas) {
      if (c.requerida) {
        c.visible = true;
      } else {
        c.visible = ids.contains(c.id);
      }
    }
    for (final c in _columnasAdicionales) {
      c.visible = ids.contains(c.id);
    }
    setState(() {});
  }

  void _buscarEquipos(String texto) async {
    setState(() {
      _filtroTexto = texto;
    });
    await _cargarEquipos(pagina: 1);
  }

  Future<void> _refrescarEquipos() async {
    await _cargarEquipos(pagina: _paginaActual);
  }

  void _irPagina(int pagina) async {
    if (pagina < 1 || pagina > _totalPaginas) return;
    await _cargarEquipos(pagina: pagina);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsPageKey, _paginaActual);
    } catch (_) {}
  }

  @override
  void dispose() {
    _hScrollCtrl.dispose();
    _vScrollCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final perms = PermissionStore.instance;

    // 1. Permiso de VER - Gatekeeper para acceso al módulo
    final bool canView = perms.can('equipos', 'ver');
    if (!canView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Equipos'),
          backgroundColor: context.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tienes permiso para acceder al módulo de equipos',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 2. Permisos específicos
    final canList = perms.can('equipos', 'listar');
    final canCreate = perms.can('equipos', 'crear');
    final canUpdate = perms.can('equipos', 'actualizar');
    final canDelete = perms.can('equipos', 'eliminar');
    final canExport = perms.can('equipos', 'exportar');
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Equipos'),
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_seleccionadosIds.isNotEmpty && canDelete)
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${_seleccionadosIds.length} seleccionados',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar seleccionados',
                  onPressed: _eliminarSeleccionados,
                ),
              ],
            ),
          // Menú de import/export existente
          if (canExport)
            EquiposImportExportMenu(
              onTemplate: _abrirPlantilla,
              onExport: _exportarEquipos,
              onImport: _importarEquipos,
              onRefresh: _refrescarEquipos,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refrescarEquipos,
            tooltip: 'Actualizar',
          ),
          PopupMenuButton<int?>(
            tooltip: 'Filtrar por estado',
            icon: const Icon(Icons.filter_list),
            itemBuilder:
                (context) => [
                  const PopupMenuItem<int?>(value: null, child: Text('Todos')),
                  ..._estados.map(
                    (e) =>
                        PopupMenuItem<int?>(value: e.id, child: Text(e.nombre)),
                  ),
                ],
            onSelected: (v) async {
              setState(() => _filtroEstadoId = v);
              await _cargarEquipos(pagina: 1);
            },
          ),
          if (!isMobile)
            IconButton(
              icon: const Icon(Icons.view_column),
              tooltip: 'Columnas',
              onPressed: _mostrarSelectorColumnas,
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Equipo',
            onPressed: canCreate ? _crearNuevoEquipo : null,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderCompacto(),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  canList
                      ? _buildContent()
                      : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No tienes permiso para listar equipos',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCompacto() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: context.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'Buscar por nombre, código, marca, modelo, placa, planta, línea...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon:
                    _filtroTexto.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _buscarEquipos('');
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _buscarEquipos,
            ),
          ),
          const SizedBox(height: 12),
          // Filtro por estado movido al AppBar (icono de filtro)
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        Widget mainList;
        if (_equipos.isEmpty) {
          mainList = const Center(child: Text('No hay equipos para mostrar'));
        } else if (_equiposFiltrados.isEmpty && _filtroTexto.isNotEmpty) {
          mainList =
              const Center(child: Text('Sin resultados para la búsqueda'));
        } else {
          mainList = isWide ? _buildTablaEquipos() : _buildCardListConScroll();
        }

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refrescarEquipos,
                color: context.primaryColor,
                child: mainList,
              ),
            ),
            _buildPaginacion(),
          ],
        );
      },
    );
  }

  /// Tooltip para textos truncados (alineado a la izquierda y en mayúsculas)
  Widget _buildTruncatedTooltip(String? texto) {
    final raw = (texto == null || texto.trim().isEmpty) ? '-' : texto.trim();
    final value = raw.toUpperCase();
    return Tooltip(
      message: value,
      waitDuration: const Duration(milliseconds: 300),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTablaEquipos() {
    // Tabla personalizada estilo Servicios con scroll horizontal/vertical siempre disponible
    final filas = _equiposFiltrados;
    final columnasVisibles =
        [
          ..._columnas,
          ..._columnasAdicionales,
        ].where((c) => c.visible).toList();
    const double selectionColWidth = 44;
    final anchoMinimo =
        selectionColWidth +
        columnasVisibles.fold<double>(0, (sum, c) => sum + c.width);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Replicar cálculo de Servicios: asegurar ancho mínimo de columnas o usar ancho disponible - 24
        final anchoTabla = math.max(anchoMinimo, constraints.maxWidth - 24);
        Widget buildHeader(double ancho) {
          return Container(
            width: ancho,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: selectionColWidth,
                    child: const SizedBox.shrink(),
                  ),
                  ...columnasVisibles.asMap().entries.map((entry) {
                    final col = entry.value;
                    return Container(
                      width: col.width,
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: GestureDetector(
                        onTap:
                            col.ordenable
                                ? () {
                                  final ascending =
                                      _sortColumnId == col.id
                                          ? !_sortAscending
                                          : true;
                                  setState(() {
                                    _sortColumnIndex = entry.key;
                                    _sortAscending = ascending;
                                    _ordenarPor(col.id, ascending);
                                    _sortColumnId = col.id;
                                  });
                                  _guardarPrefsSort();
                                }
                                : null,
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  col.titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (_sortColumnId == col.id)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  _sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }

        Widget buildRow(EquipoModel e, double ancho, int index) {
          return Container(
            width: ancho,
            height: 52,
            decoration: BoxDecoration(
              // Colores alternos de fila como en Servicios
              color:
                  (index % 2 == 0)
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: selectionColWidth,
                    child: Checkbox(
                      value: _seleccionadosIds.contains(e.id ?? -1),
                      onChanged:
                          PermissionStore.instance.can('equipos', 'eliminar')
                              ? (v) {
                                final id = e.id;
                                if (id == null) return;
                                setState(() {
                                  if (v == true) {
                                    _seleccionadosIds.add(id);
                                  } else {
                                    _seleccionadosIds.remove(id);
                                  }
                                });
                              }
                              : null,
                    ),
                  ),
                  ...columnasVisibles.map((col) {
                    Widget child;
                    final colId = col.id;
                    if (colId.startsWith('campo_')) {
                      final campoId =
                          int.tryParse(colId.replaceFirst('campo_', '')) ?? 0;
                      final campo = _camposAdicionalesUnicos.firstWhere(
                        (c) => c.id == campoId,
                        orElse:
                            () => CampoAdicionalModel(
                              id: campoId,
                              nombreCampo: '',
                              tipoCampo: '',
                              obligatorio: false,
                              modulo: '',
                            ),
                      );
                      child = _buildCellContentCampoAdicional(campo, e);
                    } else {
                      switch (colId) {
                        case 'numero':
                          child = Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              e.id?.toString() ?? '-',
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                          break;
                        case 'acciones':
                          child = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 14),
                                tooltip: 'Ver',
                                onPressed: () {
                                  if (!PermissionStore.instance.can(
                                    'equipos',
                                    'ver',
                                  )) {
                                    _mostrarSnackbar(
                                      'Sin permisos para ver equipos',
                                      Theme.of(context).colorScheme.error,
                                    );
                                    return;
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => EquipoDetailPage(equipo: e),
                                    ),
                                  );
                                },
                                color: Theme.of(context).colorScheme.primary,
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 14),
                                tooltip: 'Editar',
                                onPressed: () async {
                                  if (!PermissionStore.instance.can(
                                    'equipos',
                                    'actualizar',
                                  )) {
                                    _mostrarSnackbar(
                                      'Sin permisos para actualizar equipos',
                                      Theme.of(context).colorScheme.error,
                                    );
                                    return;
                                  }
                                  final result = await Navigator.of(
                                    context,
                                  ).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => EquipoFormPage(
                                            equipo: e,
                                            controller: ec.EquiposController(),
                                          ),
                                    ),
                                  );
                                  if (result == true && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Equipo actualizado'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    await _refrescarEquipos();
                                  }
                                },
                                color: context.warningColor,
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            ],
                          );
                          break;
                        case 'empresa':
                          child = _buildTruncatedTooltip(e.nombreEmpresa);
                          break;
                        case 'equipo':
                          child = _buildTruncatedTooltip(e.nombre);
                          break;
                        case 'codigo':
                          child = _buildTruncatedTooltip(e.codigo);
                          break;
                        case 'marca':
                          child = _buildTruncatedTooltip(e.marca);
                          break;
                        case 'modelo':
                          child = _buildTruncatedTooltip(e.modelo);
                          break;
                        case 'ciudad':
                          child = _buildTruncatedTooltip(e.ciudad);
                          break;
                        case 'placa':
                          child = _buildTruncatedTooltip(e.placa);
                          break;
                        case 'planta':
                          child = _buildTruncatedTooltip(e.planta);
                          break;
                        case 'linea':
                          child = _buildTruncatedTooltip(e.lineaProd);
                          break;
                        case 'estado':
                          child = Align(
                            alignment: Alignment.centerLeft,
                            child: _buildEstadoChip(
                              e.estadoNombre,
                              e.estadoColor,
                              estadoId: e.estadoId,
                            ),
                          );
                          break;
                        default:
                          child = const Text(
                            '-',
                            overflow: TextOverflow.ellipsis,
                          );
                      }
                    }
                    final isAcciones = col.id == 'acciones';
                    return Container(
                      width: col.width,
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isAcciones ? 6 : 10,
                        ),
                        child: child,
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }

        final tabla = SizedBox(
          width: anchoTabla,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildHeader(anchoTabla),
              ...filas.asMap().entries.map(
                (entry) => buildRow(entry.value, anchoTabla, entry.key),
              ),
            ],
          ),
        );

        // Igual que en Servicios: el Scrollbar horizontal envuelve al vertical
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Scrollbar(
              controller: _vScrollCtrl,
              thumbVisibility: true,
              thickness: 14,
              radius: const Radius.circular(7),
              trackVisibility: true,
              child: Scrollbar(
                controller: _hScrollCtrl,
                thumbVisibility: true,
                thickness: 14,
                radius: const Radius.circular(7),
                trackVisibility: true,
                notificationPredicate:
                    (notification) => notification.depth == 1,
                child: SingleChildScrollView(
                  controller: _vScrollCtrl,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _hScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: tabla,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getValorCampoAdicional(EquipoModel e, int campoId) {
    if (e.id == null) return '-';
    final lista = _valoresCamposAdicionales[e.id!];
    if (lista == null) return '-';
    final campo = lista.firstWhere(
      (c) => c.id == campoId,
      orElse:
          () => CampoAdicionalModel(
            id: 0,
            nombreCampo: '',
            tipoCampo: '',
            obligatorio: false,
            modulo: '',
            valor: null,
          ),
    );
    if (campo.id == 0) return '';
    return CamposAdicionalesApiService.formatearValorParaTabla(campo);
  }

  /// Contenido de celda para campos adicionales (alineado con Servicios)
  Widget _buildCellContentCampoAdicional(
    CampoAdicionalModel campo,
    EquipoModel equipo,
  ) {
    final valorReal = _getValorCampoAdicional(equipo, campo.id);
    final color = CamposAdicionalesApiService.getColorTipoCampo(
      campo.tipoCampo,
    );
    final icono = CamposAdicionalesApiService.getIconoTipoCampo(
      campo.tipoCampo,
    );

    if (_isLoadingCamposAdicionales && (valorReal.isEmpty)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (valorReal.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              '-',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return _buildCellContentPorTipo(campo, equipo, valorReal);
  }

  /// Contenido por tipo para campos adicionales (incluye descarga de archivo/imagen)
  Widget _buildCellContentPorTipo(
    CampoAdicionalModel campo,
    EquipoModel equipo,
    String valorReal,
  ) {
    final tipo = (campo.tipoCampo).toLowerCase();
    final color = CamposAdicionalesApiService.getColorTipoCampo(
      campo.tipoCampo,
    );
    final icono = CamposAdicionalesApiService.getIconoTipoCampo(
      campo.tipoCampo,
    );

    switch (tipo) {
      case 'imagen':
        return _buildCellImagen(icono, color, valorReal, campo, equipo);
      case 'archivo':
        return _buildCellArchivo(icono, color, valorReal, campo, equipo);
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: color, size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  valorReal.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Celda de imagen con descarga
  Widget _buildCellImagen(
    IconData icono,
    Color color,
    String valorReal,
    CampoAdicionalModel campo,
    EquipoModel equipo,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        onTap: () => _descargarArchivo(campo, equipo, 'imagen'),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  valorReal.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.download,
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Celda de archivo con descarga
  Widget _buildCellArchivo(
    IconData icono,
    Color color,
    String valorReal,
    CampoAdicionalModel campo,
    EquipoModel equipo,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        onTap: () => _descargarArchivo(campo, equipo, 'archivo'),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: context.successColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.successColor.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  valorReal.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: context.successColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.download, size: 10, color: context.successColor),
            ],
          ),
        ),
      ),
    );
  }

  /// Descargar archivo/imagen desde campo adicional
  Future<void> _descargarArchivo(
    CampoAdicionalModel campo,
    EquipoModel equipo,
    String tipoArchivo,
  ) async {
    try {
      if (equipo.id == null ||
          !_valoresCamposAdicionales.containsKey(equipo.id!)) {
        _mostrarSnackbar(
          '❌ No hay datos de campos para este equipo',
          Theme.of(context).colorScheme.error,
        );
        return;
      }

      final valores = _valoresCamposAdicionales[equipo.id!]!;
      final campoConDatos = valores.firstWhere(
        (c) => c.id == campo.id,
        orElse:
            () => CampoAdicionalModel(
              id: 0,
              nombreCampo: '',
              tipoCampo: '',
              obligatorio: false,
              modulo: '',
            ),
      );

      if (campoConDatos.id == 0 || campoConDatos.valor == null) {
        _mostrarSnackbar(
          '❌ No hay archivo asociado a este campo',
          Theme.of(context).colorScheme.error,
        );
        return;
      }

      dynamic datosArchivo = campoConDatos.valor;

      if (datosArchivo is! Map<String, dynamic>) {
        if (datosArchivo is String && datosArchivo.isNotEmpty) {
          final nombreArchivo = datosArchivo;
          final extension = nombreArchivo.split('.').last.toLowerCase();
          final carpeta = tipoArchivo == 'imagen' ? 'imagenes' : 'archivos';
          datosArchivo = {
            'tipo': tipoArchivo,
            'nombre': nombreArchivo,
            'nombre_original': nombreArchivo,
            'es_existente': true,
            'extension': extension,
            'ruta_publica':
                'uploads/campos_adicionales/$carpeta/$nombreArchivo',
          };
        } else {
          _mostrarSnackbar(
            '❌ Formato de archivo inválido',
            Theme.of(context).colorScheme.error,
          );
          return;
        }
      }

      _mostrarSnackbar(
        '⬇️ Iniciando descarga...',
        Theme.of(context).colorScheme.primary,
      );

      DownloadService.descargarCampoAdicional(
        datosArchivo: datosArchivo,
        onSuccess: (mensaje) {
          _mostrarSnackbar('✅ $mensaje', context.successColor);
        },
        onError: (error) {
          _mostrarSnackbar('❌ $error', Theme.of(context).colorScheme.error);
          if (kIsWeb) {
            final rutaPublica =
                (datosArchivo as Map<String, dynamic>)['ruta_publica'] ??
                (datosArchivo)['url_completa'];
            if (rutaPublica != null) {
              DownloadService.abrirArchivoEnNuevaPestana(
                rutaPublica.toString(),
              );
              _mostrarSnackbar(
                '📂 Archivo abierto en nueva pestaña',
                Theme.of(context).colorScheme.primary,
              );
            }
          }
        },
      );
    } catch (e) {
      _mostrarSnackbar('❌ Error: $e', Theme.of(context).colorScheme.error);
    }
  }

  void _mostrarSnackbar(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  /// Lista de tarjetas para pantallas estrechas (similar a Servicios)
  Widget _buildCardListConScroll() {
    return Scrollbar(
      thumbVisibility: true,
      interactive: true,
      thickness: 8,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _equiposFiltrados.length,
        itemBuilder: (context, index) {
          final e = _equiposFiltrados[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _seleccionadosIds.contains(e.id ?? -1),
                            onChanged: (v) {
                              if (!PermissionStore.instance.can(
                                'equipos',
                                'eliminar',
                              )) {
                                return;
                              }
                              final id = e.id;
                              if (id == null) return;
                              setState(() {
                                if (v == true) {
                                  _seleccionadosIds.add(id);
                                } else {
                                  _seleccionadosIds.remove(id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                      Expanded(
                        child: Text(
                          (e.nombre ?? 'Equipo').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      _buildEstadoChip(
                        e.estadoNombre,
                        e.estadoColor,
                        estadoId: e.estadoId,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (e.codigo != null)
                        Text('Código: ${e.codigo!.toUpperCase()}'),
                      if (e.marca != null)
                        Text('Marca: ${e.marca!.toUpperCase()}'),
                      if (e.modelo != null)
                        Text('Modelo: ${e.modelo!.toUpperCase()}'),
                      if (e.placa != null)
                        Text('Placa: ${e.placa!.toUpperCase()}'),
                      if (e.nombreEmpresa != null)
                        Text('Empresa: ${e.nombreEmpresa!.toUpperCase()}'),
                      if (e.ciudad != null)
                        Text('Ciudad: ${e.ciudad!.toUpperCase()}'),
                      if (e.planta != null)
                        Text('Planta: ${e.planta!.toUpperCase()}'),
                      if (e.lineaProd != null)
                        Text('Línea: ${e.lineaProd!.toUpperCase()}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        tooltip: 'Ver',
                        onPressed: () {
                          if (!PermissionStore.instance.can('equipos', 'ver')) {
                            _mostrarSnackbar(
                              'Sin permisos para ver equipos',
                              Theme.of(context).colorScheme.error,
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EquipoDetailPage(equipo: e),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Editar',
                        onPressed: () async {
                          if (!PermissionStore.instance.can(
                            'equipos',
                            'actualizar',
                          )) {
                            _mostrarSnackbar(
                              'Sin permisos para actualizar equipos',
                              Theme.of(context).colorScheme.error,
                            );
                            return;
                          }
                          final controller = ec.EquiposController();
                          final actualizado = await Navigator.of(
                            context,
                          ).push<bool>(
                            MaterialPageRoute(
                              builder:
                                  (_) => EquipoFormPage(
                                    controller: controller,
                                    equipo: e,
                                  ),
                            ),
                          );
                          if (actualizado == true) {
                            await _refrescarEquipos();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _mostrarSelectorColumnas() async {
    // Preparar lista actual de ids visibles (excluye obligatorias)
    final actuales = <String>[];
    for (final c in [..._columnas, ..._columnasAdicionales]) {
      if (!c.requerida && c.visible) actuales.add(c.id);
    }

    // Asegurar que campos adicionales estén cargados
    if (_camposAdicionalesUnicos.isEmpty && !_isLoadingCamposAdicionales) {
      await _cargarCamposAdicionalesBatch();
    }

    if (!mounted) return;

    // Diagnóstico: log de campos adicionales y filtrado por módulo
    try {
      final moduloDestino = 'Equipos';
      // No aceptar campos genéricos en Equipos (solo módulos explícitos de Equipos)
      final aceptarVacio = false;
      final totalAdicionales = _camposAdicionalesUnicos.length;
      final modulosOriginales = _camposAdicionalesUnicos
          .map((c) => ModuleUtils.normalizarModulo(c.modulo))
          .toSet()
          .join(', ');

      final adicionalesFiltrados =
          _camposAdicionalesUnicos
              .where(
                (c) => ModuleUtils.esModulo(
                  c.modulo,
                  moduloDestino,
                  aceptarVacioComoDestino: aceptarVacio,
                ),
              )
              .toList();

      final modulosFiltrados = adicionalesFiltrados
          .map((c) => ModuleUtils.normalizarModulo(c.modulo))
          .toSet()
          .join(', ');

      final muestraFiltrados = adicionalesFiltrados
          .take(10)
          .map((c) => '${c.id}:${ModuleUtils.normalizarModulo(c.modulo)}')
          .join(', ');

      debugPrint(
        '[Equipos ColumnModal] moduloDestino=$moduloDestino aceptarVacio=$aceptarVacio',
      );
      debugPrint(
        '[Equipos ColumnModal] adicionalesTotal=$totalAdicionales modulosOriginales=[$modulosOriginales]',
      );
      debugPrint(
        '[Equipos ColumnModal] adicionalesFiltrados=${adicionalesFiltrados.length} modulosFiltrados=[$modulosFiltrados]',
      );
      debugPrint(
        '[Equipos ColumnModal] muestraFiltrados(10)=$muestraFiltrados',
      );

      await showDialog(
        context: context,
        builder:
            (context) => ModuleColumnConfigModal(
              modulo: 'Equipos',
              aceptarVacioComoModulo: false,
              columnasActuales: actuales,
              columnasBase: [
                ColumnConfigModel(
                  id: 'numero',
                  titulo: 'N° Equipo',
                  descripcion: 'Número único del equipo',
                  icono: Icons.confirmation_number,
                  esObligatoria: true,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'acciones',
                  titulo: 'Acciones',
                  descripcion: 'Ver y editar equipo',
                  icono: Icons.handyman,
                  esObligatoria: true,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'estado',
                  titulo: 'Estado',
                  descripcion: 'Estado actual del equipo',
                  icono: Icons.flag,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'empresa',
                  titulo: 'Empresa',
                  descripcion: 'Empresa propietaria del equipo',
                  icono: Icons.business,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'equipo',
                  titulo: 'Equipo',
                  descripcion: 'Nombre del equipo',
                  icono: Icons.precision_manufacturing,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'codigo',
                  titulo: 'Código',
                  descripcion: 'Código de identificación del equipo',
                  icono: Icons.tag,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'marca',
                  titulo: 'Marca',
                  descripcion: 'Marca del equipo',
                  icono: Icons.factory,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'modelo',
                  titulo: 'Modelo',
                  descripcion: 'Modelo del equipo',
                  icono: Icons.view_in_ar,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'ciudad',
                  titulo: 'Ciudad',
                  descripcion: 'Ciudad donde se encuentra el equipo',
                  icono: Icons.location_city,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'placa',
                  titulo: 'Placa',
                  descripcion: 'Placa o registro del equipo',
                  icono: Icons.dns,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'planta',
                  titulo: 'Planta',
                  descripcion: 'Planta o sede del equipo',
                  icono: Icons.factory_outlined,
                  esObligatoria: false,
                  estaVisible: true,
                ),
                ColumnConfigModel(
                  id: 'linea',
                  titulo: 'Línea',
                  descripcion: 'Línea de producción',
                  icono: Icons.view_list,
                  esObligatoria: false,
                  estaVisible: true,
                ),
              ],
              camposAdicionales: adicionalesFiltrados,
              onColumnasChanged: (nuevas) async {
                _aplicarColumnasVisiblesDesdeIds(nuevas);

                // ✅ NUEVO: Recargar campos adicionales para asegurar sincronización
                // Esto garantiza que la tabla tenga todos los campos actualizados
                await _cargarCamposAdicionalesBatch();

                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setStringList(
                    ModuleUtils.prefsKeyColumnasVisibles('Equipos'),
                    nuevas,
                  );
                } catch (_) {}
              },
              // aceptarVacioComoModulo habilitado para no perder campos sin módulo
              // (algunas respuestas de API pueden venir con módulo vacío)
              // ya configurado arriba
            ),
      );
    } catch (e) {
      debugPrint('[Equipos ColumnModal] error preparando modal: $e');
    }
  }

  Widget _buildPaginacion() {
    if (_isLoading) return const SizedBox.shrink();
    // Siempre mostrar para permitir cambiar tamaño de página
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _paginaActual > 1 ? () => _irPagina(_paginaActual - 1) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Text(
                'Página $_paginaActual de $_totalPaginas',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Text('Por página:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _limite,
                underline: const SizedBox.shrink(),
                items:
                    const [10, 20, 50, 100]
                        .map(
                          (v) => DropdownMenuItem<int>(
                            value: v,
                            child: Text('$v'),
                          ),
                        )
                        .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  if (mounted) {
                    setState(() {
                      _limite = v;
                    });
                  }
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(_prefsPageSizeKey, v);
                    // Al cambiar tamaño, resetear a página 1 para evitar inconsistencias
                    await prefs.setInt(_prefsPageKey, 1);
                  } catch (_) {}
                  await _cargarEquipos(pagina: 1);
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _paginaActual < _totalPaginas
                    ? () => _irPagina(_paginaActual + 1)
                    : null,
          ),
        ],
      ),
    );
  }

  // Acciones AppBar / Menú
  Future<void> _abrirPlantilla() async {
    // Permitir si el usuario puede listar o ver
    if (!PermissionStore.instance.can('equipos', 'listar') &&
        !PermissionStore.instance.can('equipos', 'ver')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin permisos para acceder a la plantilla de equipos',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final bytes = await EquiposApiService.descargarPlantillaEquipos();
      if (bytes != null) {
        await dl.saveBytes(
          'plantilla_equipos.xlsx',
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plantilla de equipos descargada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo descargar la plantilla (JWT requerido)',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar plantilla: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportarEquipos() async {
    if (!PermissionStore.instance.can('equipos', 'exportar')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin permisos para exportar equipos'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final bytes = await EquiposApiService.exportarEquipos();
      if (bytes != null) {
        await dl.saveBytes(
          'equipos.xlsx',
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exportación de equipos completada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo exportar equipos (JWT requerido)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exportando equipos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importarEquipos() async {
    if (!PermissionStore.instance.can('equipos', 'crear')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin permisos para importar equipos'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Archivo vacío o no soportado');
      }

      final base64String = base64.encode(bytes);
      final fileName = file.name;

      final resultApi = await EquiposApiService.importarEquipos(
        archivoBase64: base64String,
        nombreArchivo: fileName,
      );
      final ok =
          resultApi != null &&
          (resultApi['success'] == true || resultApi['status'] == 'ok');
      final msg =
          ok
              ? (resultApi['message'] ?? 'Importación de equipos completada')
              : (resultApi?['error'] ??
                  resultApi?['message'] ??
                  'Error importando equipos');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
      if (ok) {
        await _cargarEquipos(pagina: 1);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importando equipos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _crearNuevoEquipo() async {
    if (!PermissionStore.instance.can('equipos', 'crear')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin permisos para crear equipos'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // 🛡️ REGLA CRÍTICA: No permitir creación si no hay estados cargados
    if (_estados.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Configuración requerida'),
            content: const Text(
              'No se pueden crear equipos porque no hay estados configurados para este módulo.\n\n'
              'Por favor, cree el flujo de estados antes de continuar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final ctrl = ec.EquiposController();
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EquipoFormPage(controller: ctrl)));
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Equipo creado'),
          backgroundColor: Colors.green,
        ),
      );
      await _cargarEquipos(pagina: 1);
    }
  }

  // ======== Ordenamiento ========
  void _ordenarPor(String columnaId, bool asc) {
    int compare(
      EquipoModel a,
      EquipoModel b,
      String? Function(EquipoModel) sel,
    ) {
      final va = sel(a)?.toLowerCase() ?? '';
      final vb = sel(b)?.toLowerCase() ?? '';
      return asc ? va.compareTo(vb) : vb.compareTo(va);
    }

    setState(() {
      _sortColumnId = columnaId;
      _sortAscending = asc; // Mantener estado y persistencia coherentes
      switch (columnaId) {
        case 'numero':
          _equiposFiltrados.sort((a, b) {
            final va = a.id ?? 0;
            final vb = b.id ?? 0;
            return asc ? va.compareTo(vb) : vb.compareTo(va);
          });
          break;
        case 'empresa':
          _equiposFiltrados.sort(
            (a, b) => compare(a, b, (e) => e.nombreEmpresa),
          );
          break;
        case 'equipo':
          _equiposFiltrados.sort((a, b) => compare(a, b, (e) => e.nombre));
          break;
        case 'codigo':
          _equiposFiltrados.sort((a, b) => compare(a, b, (e) => e.codigo));
          break;
        case 'marca':
          _equiposFiltrados.sort((a, b) => compare(a, b, (e) => e.marca));
          break;
        case 'modelo':
          _equiposFiltrados.sort((a, b) => compare(a, b, (e) => e.modelo));
          break;
        case 'ciudad':
          _equiposFiltrados.sort((a, b) => compare(a, b, (e) => e.ciudad));
          break;
        case 'placa':
          _equiposFiltrados.sort((a, b) => compare(a, b, (e) => e.placa));
          break;
        case 'planta':
          _equiposFiltrados.sort((a, b) => compare(a, b, (e) => e.planta));
          break;
        case 'linea':
          _equiposFiltrados.sort((a, b) => compare(a, b, (e) => e.lineaProd));
          break;
        case 'estado':
          _equiposFiltrados.sort(
            (a, b) => compare(a, b, (e) => e.estadoNombre),
          );
          break;
      }
    });
    _guardarPrefsSort();
  }

  // ======== Eliminación con validación ========
  Future<void> _eliminarSeleccionados() async {
    if (!PermissionStore.instance.can('equipos', 'eliminar')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin permisos para eliminar equipos'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (_seleccionadosIds.isEmpty) return;
    // Cargar servicios para verificar uso
    List<ServicioModel> servicios = [];
    try {
      final r = await ServiciosApiService.listarServicios(limite: 1000);
      servicios = (r['servicios'] as List<ServicioModel>);
    } catch (_) {}

    final usados = <int>{};
    final libres = <int>{};
    for (final id in _seleccionadosIds) {
      final estaUsado = servicios.any((s) => s.idEquipo == id);
      if (estaUsado) {
        usados.add(id);
      } else {
        libres.add(id);
      }
    }

    if (libres.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se puede eliminar: equipos están vinculados a servicios',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Eliminar equipos'),
            content: Text(
              usados.isEmpty
                  ? 'Se eliminarán ${libres.length} equipo(s).'
                  : 'Se eliminarán ${libres.length} equipo(s).\n'
                      'No se eliminarán ${usados.length} por estar usados en servicios.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
    if (confirmar != true) return;

    int eliminados = 0;
    for (final id in libres) {
      final ok = await EquiposApiService.eliminarEquipo(id: id);
      if (ok) eliminados++;
    }

    setState(() {
      _seleccionadosIds.clear();
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Eliminados: $eliminados. Bloqueados: ${usados.length}.',
          ),
          backgroundColor: eliminados > 0 ? Colors.green : Colors.orange,
        ),
      );
    }
    await _refrescarEquipos();
  }

}

class _ColDef {
  final String id;
  final String titulo;
  final bool requerida;
  bool visible;
  final bool ordenable;
  final double width;

  _ColDef({
    required this.id,
    required this.titulo,
    this.requerida = false,
    this.visible = true,
    this.ordenable = true,
    this.width = 200,
  });
}
