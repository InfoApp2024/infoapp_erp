/// ============================================================================
/// ARCHIVO: servicios_controller.dart
///
/// PROPSITO: Controlador de estado (State Management) que:
/// - Gestiona el estado global de servicios
/// - Maneja la comunicacin con la API
/// - Controla conexiones WebSocket
/// - Implementa cache y optimizaciones
/// - Notifica cambios a los widgets suscritos
///
/// USO: Se usa con ChangeNotifier/Provider para estado reactivo
/// FUNCIN: Capa de lgica de negocio que separa la UI de la comunicacin con el backend.
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'dart:async';
import '../models/servicio_model.dart';
import '../services/servicios_api_service.dart';
import '../services/servicios_websocket_service.dart';
import '../models/servicio_evento_model.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:infoapp/core/utils/servicios_cache.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import '../services/servicios_sync_queue.dart';

class ServiciosController extends ChangeNotifier {
  List<ServicioModel> _servicios = [];
  bool _isLoading = false;
  String? _error;

  // Variables de paginacin
  int _paginaActual = 1;
  int _totalPaginas = 1;
  int _totalRegistros = 0;
  int _limitePorPagina = 20;
  bool _tieneSiguiente = false;
  bool _tieneAnterior = false;

  //  NUEVO: Estado de filtros actuales (para paginacin)
  String? _ultimoBuscar;
  String? _ultimoEstado;
  String? _ultimoTipo;
  dynamic _ultimoFinalizados;

  //  NUEVAS propiedades WebSocket
  final ServiciosWebSocketService _webSocketService =
      ServiciosWebSocketService();
  StreamSubscription<ServicioEventoModel>? _eventosSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  bool _webSocketConectado = false;
  bool _webSocketInicializado = false;
  StreamSubscription<bool>? _connectivitySubscription;

  // Getters bsicos
  List<ServicioModel> get servicios => _servicios;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getters de paginacin
  int get paginaActual => _paginaActual;
  int get totalPaginas => _totalPaginas;
  int get totalRegistros => _totalRegistros;
  int get limitePorPagina => _limitePorPagina;
  bool get tieneSiguiente => _tieneSiguiente;
  bool get tieneAnterior => _tieneAnterior;

  //  NUEVOS getters WebSocket
  bool get webSocketConectado => _webSocketConectado;
  bool get webSocketInicializado => _webSocketInicializado;

  // Getter para el termino de busqueda actual
  String? get buscar => _ultimoBuscar;
  bool get isSearchActive => _ultimoBuscar != null && _ultimoBuscar!.isNotEmpty;

  /// Cargar siguiente pagina
  Future<void> cargarSigPagina() async {
    if (_tieneSiguiente && !_isLoading) {
      await irAPagina(_paginaActual + 1);
    }
  }

  //  Constructor con inicializacin WebSocket
  ServiciosController() {
    _inicializarWebSocket();
    _inicializarConectividad();
  }

  ///  NUEVO: Inicializar WebSocket
  void _inicializarWebSocket() {
    // Escuchar eventos de servicios en tiempo real
    _eventosSubscription = _webSocketService.serviciosCambios.listen(
      _manejarEventoServicio,
      onError: (error) {
        _error = 'Error en conexin tiempo real';
        notifyListeners();
      },
    );

    // Escuchar estado de conexin (sin logs)
    _connectionSubscription = _webSocketService.connectionStatus.listen((
      conectado,
    ) {
      final estadoAnterior = _webSocketConectado;
      _webSocketConectado = conectado;

      if (estadoAnterior != conectado) {
        notifyListeners();
      }
    });

    _webSocketInicializado = true;

    // Conectar automticamente
    Timer(const Duration(milliseconds: 500), _conectarWebSocket);
  }

  ///  NUEVO: Inicializar escucha de conectividad y procesar cola offline
  void _inicializarConectividad() {
    // Iniciar chequeo peridico si no est corriendo
    ConnectivityService.instance.start();

    // Al recuperar conexin, procesar cola pendiente
    _connectivitySubscription = ConnectivityService.instance.status$.listen((
      conectado,
    ) async {
      if (conectado) {
        try {
          final aplicadas = await ServiciosSyncQueue.processPending();
          if (aplicadas > 0) {
            // Refrescar lista para reflejar cambios
            await cargarServicios(pagina: _paginaActual);
          }
        } catch (_) {
          // Silencioso: no romper UI si procesamiento falla
        }
      }
    });
  }

  ///  NUEVO: Conectar WebSocket
  Future<void> _conectarWebSocket() async {
    try {
      //       print(' Intentando conectar WebSocket...');
      await _webSocketService.conectar();
    } catch (e) {
      //       print(' Error conectando WebSocket: $e');
      _error = 'Error conectando tiempo real: $e';
      notifyListeners();
    }
  }

  ///  NUEVO: Manejar eventos de servicios en tiempo real
  void _manejarEventoServicio(ServicioEventoModel evento) {
    try {
      switch (evento.tipo) {
        case ServicioEventoModel.servicioCreado:
          if (evento.servicio != null) {
            _agregarServicioTiempoReal(evento.servicio!);
          }
          break;

        case ServicioEventoModel.servicioActualizado:
          if (evento.servicio != null) {
            _actualizarServicioTiempoReal(evento.servicio!);
          }
          break;

        case ServicioEventoModel.servicioEliminado:
          if (evento.servicioId != null) {
            _eliminarServicioTiempoReal(evento.servicioId!);
          }
          break;

        case ServicioEventoModel.servicioEstadoCambiado:
          if (evento.servicio != null) {
            _actualizarServicioTiempoReal(evento.servicio!);
          }
          break;

        default:
        //           print(' Tipo de evento WebSocket no manejado: ${evento.tipo}');
      }
    } catch (e) {
      //       print(' Error manejando evento WebSocket: $e');
    }
  }

  ///  NUEVO: Agregar servicio en tiempo real (desde WebSocket)
  void _agregarServicioTiempoReal(ServicioModel nuevoServicio) {
    try {
      // Verificar que no exista ya para evitar duplicados
      final existe = _servicios.any((s) => s.id == nuevoServicio.id);
      if (!existe) {
        _servicios.insert(0, nuevoServicio); // Agregar al inicio
        notifyListeners();
        //         print(' Servicio agregado en tiempo real: #${nuevoServicio.oServicio}');
      } else {
        //         print(' Servicio ya existe, actualizando: #${nuevoServicio.oServicio}');
        _actualizarServicioTiempoReal(nuevoServicio);
      }
    } catch (e) {
      //       print(' Error agregando servicio en tiempo real: $e');
    }
  }

  ///  NUEVO: Actualizar servicio en tiempo real (desde WebSocket)
  ///  CORRECCIÓN: Merge defensivo para no sobreescribir campos enriquecidos
  ///  con valores null del mensaje WS (que puede ser un objeto parcial)
  void _actualizarServicioTiempoReal(ServicioModel servicioActualizado) {
    try {
      final index = _servicios.indexWhere(
        (s) => s.id == servicioActualizado.id,
      );
      if (index != -1) {
        // MERGE DEFENSIVO: Si el objeto WS tiene campos enriquecidos nulos,
        // conservar los del objeto existente (que vino de la API con JOINs completos)
        final existente = _servicios[index];
        final merged = servicioActualizado.copyWith(
          estadoNombre:
              servicioActualizado.estadoNombre?.isNotEmpty == true
                  ? servicioActualizado.estadoNombre
                  : existente.estadoNombre,
          estadoColor:
              servicioActualizado.estadoColor?.isNotEmpty == true
                  ? servicioActualizado.estadoColor
                  : existente.estadoColor,
          equipoNombre:
              servicioActualizado.equipoNombre?.isNotEmpty == true
                  ? servicioActualizado.equipoNombre
                  : existente.equipoNombre,
          clienteNombre:
              servicioActualizado.clienteNombre?.isNotEmpty == true
                  ? servicioActualizado.clienteNombre
                  : existente.clienteNombre,
          nombreEmp:
              servicioActualizado.nombreEmp?.isNotEmpty == true
                  ? servicioActualizado.nombreEmp
                  : existente.nombreEmp,
          actividadNombre:
              servicioActualizado.actividadNombre?.isNotEmpty == true
                  ? servicioActualizado.actividadNombre
                  : existente.actividadNombre,
        );
        _servicios[index] = merged;
        // CREATE NEW LIST INSTANCE TO TRIGGER REACTIVE UI (didUpdateWidget)
        _servicios = List<ServicioModel>.from(_servicios);
        notifyListeners();
      } else {
        _agregarServicioTiempoReal(servicioActualizado);
      }
    } catch (e) {
      // ignore
    }
  }

  ///  NUEVO: Eliminar servicio en tiempo real (desde WebSocket)
  void _eliminarServicioTiempoReal(int servicioId) {
    try {
      final index = _servicios.indexWhere((s) => s.id == servicioId);
      if (index != -1) {
        final servicio = _servicios.removeAt(index);
        notifyListeners();
        //         print(' Servicio eliminado en tiempo real: #${servicio.oServicio}');
      } else {
        //         print(' Servicio no encontrado para eliminar: ID $servicioId');
      }
    } catch (e) {
      //       print(' Error eliminando servicio en tiempo real: $e');
    }
  }

  /// Cargar servicios desde el servidor (paginado)
  Future<void> cargarServicios({
    int? pagina,
    int? limite,
    String? buscar,
    String? estado,
    String? tipo,
    dynamic finalizados, //  NUEVO: Filtro server-side
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Offline-first: si no hay conexin, cargar desde cach y salir
      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        final cache = await ServiciosCache.loadList();
        if (cache != null && cache.isNotEmpty) {
          _servicios = cache;
          _totalRegistros = cache.length;
          _paginaActual = 1;
          _totalPaginas = 1;
          _tieneSiguiente = false;
          _tieneAnterior = false;
          _isLoading = false;
          notifyListeners();
          return;
        }
        _error = 'Sin conexin y sin datos guardados. Conctate para cargar.';
        _isLoading = false;
        notifyListeners();
        return;
        return;
      }

      //  Guardar estado de filtros
      if (buscar != null) _ultimoBuscar = buscar;
      if (estado != null) _ultimoEstado = estado;
      if (tipo != null) _ultimoTipo = tipo;
      if (finalizados != null) _ultimoFinalizados = finalizados;

      //       print(' Controller: Cargando servicios paginados desde servidor...');

      final resultado = await ServiciosApiService.listarServicios(
        pagina: pagina ?? _paginaActual,
        limite: limite ?? _limitePorPagina,
        buscar: buscar ?? _ultimoBuscar,
        estado: estado ?? _ultimoEstado,
        tipo: tipo ?? _ultimoTipo,
        finalizados: finalizados ?? _ultimoFinalizados,
      );

      _servicios = resultado['servicios'] as List<ServicioModel>;
      _totalRegistros = resultado['total'] ?? _servicios.length;
      _paginaActual = resultado['pagina'] ?? 1;
      _totalPaginas = resultado['totalPaginas'] ?? 1;
      _tieneSiguiente = resultado['tieneSiguiente'] ?? false;
      _tieneAnterior = resultado['tieneAnterior'] ?? false;

      //  Guardar en cache para modo offline
      await ServiciosCache.saveList(_servicios);
      //       print(' Controller: ${_servicios.length} servicios cargados (pgina $_paginaActual de $_totalPaginas)');
    } catch (e) {
      // Fallback a datos cacheados si existen
      final cache = await ServiciosCache.loadList();
      if (cache != null && cache.isNotEmpty) {
        _servicios = cache;
        _totalRegistros = cache.length;
        _paginaActual = 1;
        _totalPaginas = 1;
        _tieneSiguiente = false;
        _tieneAnterior = false;
        _error = null; // No bloquear la UI si tenemos datos en cach
        //         print(' Controller: Sin conexin. Datos cargados desde cache (${cache.length}).');
      } else {
        _error = NetErrorMessages.from(e, contexto: 'cargar servicios');
        //         print(' Controller: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cambiar de pgina
  Future<void> irAPagina(int pagina) async {
    if (pagina < 1 || pagina > _totalPaginas) return;
    await cargarServicios(pagina: pagina);
  }

  /// Cambiar lmite por pgina
  Future<void> cambiarLimite(int nuevoLimite) async {
    if (nuevoLimite < 1) return;
    _limitePorPagina = nuevoLimite;
    await cargarServicios(pagina: 1, limite: nuevoLimite);
  }

  ///  NUEVO: Establecer lmite sin recargar (para inicializacin)
  void establecerLimiteSinRecargar(int nuevoLimite) {
    if (nuevoLimite < 1) return;
    _limitePorPagina = nuevoLimite;
  }

  /// Crear servicio y recargar lista
  Future<bool> crearServicio(ServicioModel servicio) async {
    try {
      //       print(' Controller: Creando servicio...');

      final resultado = await ServiciosApiService.crearServicio(servicio);
      if (resultado.isSuccess && resultado.data != null) {
        //  NUEVO: Agregar localmente al inicio de la lista (ndice 0)
        agregarServicioLocal(resultado.data!);

        //  NUEVO: Notificar creacin local via WebSocket (opcional)
        _notificarCreacionLocal(resultado.data!);

        return true;
      } else {
        _error = resultado.error ?? 'Error creando servicio';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error creando servicio: $e';
      notifyListeners();
      return false;
    }
  }

  /// Actualizar servicio y recargar lista
  Future<bool> actualizarServicio(ServicioModel servicio) async {
    try {
      //       print(' Controller: Actualizando servicio ID: ${servicio.id}...');

      final resultado = await ServiciosApiService.actualizarServicio(servicio);
      if (resultado.isSuccess) {
        //         print(' Controller: Servicio actualizado - ID: ${servicio.id}');

        //  NUEVO: Notificar actualizacin local via WebSocket (opcional)
        _notificarActualizacionLocal(servicio);

        //  OPTIMIZACIN: Actualizar localmente en lugar de recargar todo
        actualizarServicioLocal(servicio);
        return true;
      } else {
        _error = resultado.error ?? 'Error actualizando servicio';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error actualizando servicio: $e';
      notifyListeners();
      return false;
    }
  }

  /// Anular servicio y recargar lista
  Future<bool> anularServicio({
    required int servicioId,
    required int estadoFinalId, // AGREGAR este parmetro
    required String razon,
  }) async {
    try {
      //       print(' Controller: Anulando servicio ID: $servicioId...');

      _error = null;
      notifyListeners();

      final resultado = await ServiciosApiService.anularServicio(
        servicioId: servicioId,
        estadoFinalId: estadoFinalId, // AGREGAR este parmetro
        razon: razon,
      );

      if (resultado.isSuccess) {
        // MERGE DEFENSIVO: Actualizar localmente preservando datos enriquecidos
        final servicio = obtenerServicioPorId(servicioId);
        if (servicio != null) {
          actualizarServicioLocal(
            servicio.copyWith(
              anularServicio: true,
              // estadoId se actualiza pero estadoNombre NO lo tenemos aquí —
              // lo dejamos en null para que el usuario vea el cambio solo tras reload,
              // pero preservamos el resto de los campos enriquecidos.
              razon: razon,
            ),
          );
        }
        return true;
      } else {
        _error = resultado.error ?? 'Error anulando servicio';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error anulando servicio: $e';
      notifyListeners();
      return false;
    }
  }

  /// Buscar servicios localmente (desde lista cargada)
  List<ServicioModel> buscarServicios(String termino) {
    if (termino.isEmpty) return List<ServicioModel>.from(_servicios);

    final terminoLower = termino.toLowerCase();
    return _servicios.where((servicio) {
      return servicio.ordenCliente?.toLowerCase().contains(terminoLower) ==
              true ||
          servicio.oServicio?.toString().contains(termino) == true ||
          servicio.equipoNombre?.toLowerCase().contains(terminoLower) == true ||
          servicio.nombreEmp?.toLowerCase().contains(terminoLower) == true ||
          servicio.placa?.toLowerCase().contains(terminoLower) == true ||
          servicio.centroCosto?.toLowerCase().contains(terminoLower) == true ||
          servicio.tipoMantenimiento?.toLowerCase().contains(terminoLower) ==
              true ||
          servicio.estadoNombre?.toLowerCase().contains(terminoLower) == true ||
          servicio.clienteNombre?.toLowerCase().contains(terminoLower) == true;
    }).toList();
  }

  /// AGREGADO: Obtener copia de la lista de servicios (para forzar reactividad)
  List<ServicioModel> get serviciosCopia => List<ServicioModel>.from(_servicios);

  /// Filtrar servicios por estado
  List<ServicioModel> filtrarPorEstado(String? estado) {
    if (estado == null || estado.isEmpty) return _servicios;
    return _servicios.where((s) => s.estadoNombre == estado).toList();
  }

  /// Filtrar servicios por tipo
  List<ServicioModel> filtrarPorTipo(String? tipo) {
    if (tipo == null || tipo.isEmpty) return _servicios;
    return _servicios.where((s) => s.tipoMantenimiento == tipo).toList();
  }

  /// Obtener estadsticas de servicios
  Map<String, int> obtenerEstadisticas() {
    return {
      'total': _servicios.length,
      'activos': _servicios.where((s) => !s.estaAnulado).length,
      'finalizados': _servicios.where((s) => s.estaFinalizado).length,
      'con_repuestos': _servicios.where((s) => s.tieneRepuestos).length,
    };
  }

  /// Obtener tipos nicos de mantenimiento
  List<String> obtenerTiposUnicos() {
    final tipos = <String>{};
    for (var servicio in _servicios) {
      if (servicio.tipoMantenimiento?.isNotEmpty == true) {
        tipos.add(servicio.tipoMantenimiento!);
      }
    }
    return tipos.toList()..sort();
  }

  /// Obtener estados nicos
  List<String> obtenerEstadosUnicos() {
    final estados = <String>{};
    for (var servicio in _servicios) {
      if (servicio.estadoNombre?.isNotEmpty == true) {
        estados.add(servicio.estadoNombre!);
      }
    }
    return estados.toList()..sort();
  }

  /// Limpiar errores
  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  /// Verificar si hay datos cargados
  bool get tieneServicios => _servicios.isNotEmpty;

  /// Obtener servicio por ID
  ServicioModel? obtenerServicioPorId(int id) {
    try {
      return _servicios.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtener servicios recientes (ltimos por nmero de orden)
  List<ServicioModel> obtenerServiciosRecientes({int limite = 10}) {
    final serviciosOrdenados = List<ServicioModel>.from(_servicios);
    serviciosOrdenados.sort(
      (a, b) => (b.oServicio ?? 0).compareTo(a.oServicio ?? 0),
    );
    return serviciosOrdenados.take(limite).toList();
  }

  /// Buscar en servidor con filtros especficos
  Future<List<ServicioModel>> buscarEnServidor({
    String? buscar,
    String? estado,
    String? tipo,
    int pagina = 1,
    int limite = 50,
  }) async {
    try {
      final resultado = await ServiciosApiService.listarServicios(
        pagina: pagina,
        limite: limite,
        buscar: buscar,
        estado: estado,
        tipo: tipo,
      );

      return resultado['servicios'] as List<ServicioModel>;
    } catch (e) {
      //       print(' Error en bsqueda de servidor: $e');
      rethrow;
    }
  }

  /// Actualizar un servicio especfico en la lista local
  void actualizarServicioLocal(ServicioModel servicioActualizado) {
    final index = _servicios.indexWhere((s) => s.id == servicioActualizado.id);
    if (index != -1) {
      _servicios[index] = servicioActualizado;
      // CREATE NEW LIST INSTANCE TO TRIGGER REACTIVE UI (didUpdateWidget)
      _servicios = List<ServicioModel>.from(_servicios);
      notifyListeners();
      //       print(' Servicio actualizado localmente: #${servicioActualizado.oServicio}');
    } else {
      //       print(' Servicio no encontrado para actualizar localmente: #${servicioActualizado.oServicio}');
    }
  }

  /// Agregar un servicio a la lista local
  void agregarServicioLocal(ServicioModel nuevoServicio) {
    // Verificar que no exista ya
    final existe = _servicios.any((s) => s.id == nuevoServicio.id);
    if (!existe) {
      _servicios.insert(0, nuevoServicio);
      notifyListeners();
      //       print(' Servicio agregado localmente: #${nuevoServicio.oServicio}');
    } else {
      //       print(' Servicio ya existe localmente: #${nuevoServicio.oServicio}');
    }
  }

  /// Remover un servicio de la lista local
  void removerServicioLocal(int servicioId) {
    final index = _servicios.indexWhere((s) => s.id == servicioId);
    if (index != -1) {
      final servicio = _servicios.removeAt(index);
      notifyListeners();
      //       print(' Servicio removido localmente: #${servicio.oServicio}');
    } else {
      //       print(' Servicio no encontrado para remover localmente: ID $servicioId');
    }
  }

  ///  NUEVO: Reconectar WebSocket manualmente
  Future<void> reconectarWebSocket() async {
    //     print(' Reconectando WebSocket manualmente...');
    try {
      _webSocketService.desconectar();
      await Future.delayed(const Duration(seconds: 1));
      await _conectarWebSocket();
    } catch (e) {
      //       print(' Error en reconexin manual: $e');
      _error = 'Error reconectando: $e';
      notifyListeners();
    }
  }

  ///  NUEVO: Desconectar WebSocket manualmente
  void desconectarWebSocket() {
    //     print(' Desconectando WebSocket manualmente...');
    _webSocketService.desconectar();
  }

  ///  NUEVO: Conectar WebSocket manualmente
  Future<void> conectarWebSocket() async {
    //     print(' Conectando WebSocket manualmente...');
    await _conectarWebSocket();
  }

  ///  NUEVO: Forzar actualizacin completa (WebSocket + API)
  Future<void> forzarActualizacionCompleta() async {
    //     print(' Forzando actualizacin completa...');
    try {
      // 1. Reconectar WebSocket
      await reconectarWebSocket();

      // 2. Recargar servicios desde API
      await cargarServicios();

      //       print(' Actualizacin completa finalizada');
    } catch (e) {
      //       print(' Error en actualizacin completa: $e');
      _error = 'Error en actualizacin completa: $e';
      notifyListeners();
    }
  }

  //  MTODOS PRIVADOS PARA NOTIFICACIONES WEBSOCKET

  /// Notificar creacin local al WebSocket
  void _notificarCreacionLocal(ServicioModel servicio) {
    try {
      _webSocketService.notificarCambioLocal(
        ServicioEventoModel.servicioCreado,
        {'servicio': servicio.toJson()},
      );
      //       print(' Notificacin de creacin enviada via WebSocket');
    } catch (e) {
      //       print(' Error notificando creacin local: $e');
    }
  }

  /// Notificar actualizacin local al WebSocket
  void _notificarActualizacionLocal(ServicioModel servicio) {
    try {
      _webSocketService.notificarCambioLocal(
        ServicioEventoModel.servicioActualizado,
        {'servicio': servicio.toJson()},
      );
      //       print(' Notificacin de actualizacin enviada via WebSocket');
    } catch (e) {
      //       print(' Error notificando actualizacin local: $e');
    }
  }

  ///  NUEVO: Refrescar un servicio especfico sin loading global
  Future<void> refrescarServicioEspecifico(int id) async {
    try {
      final response = await ServiciosApiService.obtenerServicio(id);
      if (response.isSuccess && response.data != null) {
        _agregarServicioTiempoReal(response.data!);
      }
    } catch (e) {
      // Silently fail - the service is already in the list with partial data
    }
  }

  ///  DISPOSE MEJORADO: Limpiar recursos WebSocket
  @override
  void dispose() {
    //     print(' Limpiando recursos del ServiciosController...');

    // Limpiar suscripciones WebSocket
    _eventosSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectivitySubscription?.cancel();

    // Desconectar y limpiar WebSocket service
    _webSocketService.dispose();

    // Limpiar estado
    _webSocketInicializado = false;
    _webSocketConectado = false;

    //     print(' Recursos del ServiciosController limpiados');
    super.dispose();
  }
}
