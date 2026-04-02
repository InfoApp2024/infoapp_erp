/// ============================================================================
/// ARCHIVO: inspecciones_provider.dart
///
/// PROPÓSITO: Provider para gestión de estado de inspecciones
/// - Maneja la lista de inspecciones
/// - Gestiona paginación y filtros
/// - Coordina llamadas a la API
/// - Escucha actualizaciones en tiempo real
/// ============================================================================
library;


import 'package:flutter/foundation.dart';
import '../models/inspeccion_model.dart';
import '../services/inspecciones_api_service.dart';
import '../services/inspecciones_websocket_service.dart';
import '../models/evidencia_seleccionada.dart';
import 'dart:async';

class InspeccionesProvider with ChangeNotifier {
  // Estado
  List<InspeccionModel> _inspecciones = [];
  InspeccionModel? _inspeccionSeleccionada;
  bool _isLoading = false;
  String? _error;

  // Paginación
  int _paginaActual = 1;
  int _totalPaginas = 1;
  int _totalRegistros = 0;
  final int _limite = 20;

  // Filtros
  String? _buscar;
  String? _estadoFiltro;
  String? _sitioFiltro;
  int? _equipoIdFiltro;
  String? _fechaDesde;
  String? _fechaHasta;

  // WebSocket
  final InspeccionesWebSocketService _wsService = InspeccionesWebSocketService();
  StreamSubscription? _wsSubscription;

  // Getters
  List<InspeccionModel> get inspecciones => _inspecciones;
  InspeccionModel? get inspeccionSeleccionada => _inspeccionSeleccionada;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get paginaActual => _paginaActual;
  int get totalPaginas => _totalPaginas;
  int get totalRegistros => _totalRegistros;
  String? get estadoFiltro => _estadoFiltro;
  bool get tieneSiguiente => _paginaActual < _totalPaginas;
  bool get tieneAnterior => _paginaActual > 1;

  InspeccionesProvider() {
    _inicializarWebSocket();
  }

  void _inicializarWebSocket() {
    _wsService.conectar();
    _wsSubscription = _wsService.inspeccionesCambios.listen((evento) {
      // Recargar lista cuando hay cambios
      cargarInspecciones(mantenerPagina: true);
    });
  }

  /// Cargar inspecciones con filtros y paginación
  Future<void> cargarInspecciones({bool mantenerPagina = false}) async {
    if (!mantenerPagina) {
      _paginaActual = 1;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resultado = await InspeccionesApiService.listarInspecciones(
        pagina: _paginaActual,
        limite: _limite,
        buscar: _buscar,
        estado: _estadoFiltro,
        sitio: _sitioFiltro,
        equipoId: _equipoIdFiltro,
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
      );

      _inspecciones = resultado['inspecciones'] as List<InspeccionModel>;
      _totalRegistros = resultado['total'] as int;
      _paginaActual = resultado['pagina'] as int;
      _totalPaginas = resultado['totalPaginas'] as int;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar detalle de una inspección
  Future<void> cargarInspeccion(int inspeccionId, {bool silencioso = false}) async {
    if (!silencioso) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _inspeccionSeleccionada = await InspeccionesApiService.obtenerInspeccion(inspeccionId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }



  /// Crear nueva inspección
  Future<bool> crearInspeccion({
    required int estadoId,
    required String sitio,
    required String fechaInspe,
    required int equipoId,
    required List<int> inspectores,
    required List<int> sistemas,
    required List<int> actividades,
    List<EvidenciaSeleccionada>? evidencias,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resultado = await InspeccionesApiService.crearInspeccion(
        estadoId: estadoId,
        sitio: sitio,
        fechaInspe: fechaInspe,
        equipoId: equipoId,
        inspectores: inspectores,
        sistemas: sistemas,
        actividades: actividades,
        evidencias: evidencias,
      );

      _isLoading = false;
      notifyListeners();

      // Recargar lista (sin await para no bloquear el retorno)
      cargarInspecciones();
      return true;
          return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualizar inspección
  Future<bool> actualizarInspeccion({
    required int inspeccionId,
    int? estadoId,
    String? sitio,
    String? fechaInspe,
    int? equipoId,
    List<int>? inspectores,
    List<int>? sistemas,
    List<int>? actividades,
    Map<int, String>? notasEliminacion,
    List<EvidenciaSeleccionada>? evidencias,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final exito = await InspeccionesApiService.actualizarInspeccion(
        inspeccionId: inspeccionId,
        estadoId: estadoId,
        sitio: sitio,
        fechaInspe: fechaInspe,
        equipoId: equipoId,
        inspectores: inspectores,
        sistemas: sistemas,
        actividades: actividades,
        notasEliminacion: notasEliminacion,
        evidencias: evidencias,
      );

      _isLoading = false;
      notifyListeners();

      if (exito) {
        // Recargar lista y detalle si está seleccionado (esperar para sincronía)
        await cargarInspecciones(mantenerPagina: true);
        if (_inspeccionSeleccionada?.id == inspeccionId) {
          await cargarInspeccion(inspeccionId, silencioso: true);
        }
      }

      return exito;
    } catch (e) {
      debugPrint('ERROR EN ACTUALIZAR INSPECCION: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Eliminar inspección
  Future<bool> eliminarInspeccion(int inspeccionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final exito = await InspeccionesApiService.eliminarInspeccion(inspeccionId);

      _isLoading = false;
      notifyListeners();

      if (exito) {
        // Recargar lista
        await cargarInspecciones(mantenerPagina: true);
        if (_inspeccionSeleccionada?.id == inspeccionId) {
          _inspeccionSeleccionada = null;
        }
      }

      return exito;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Eliminar actividad
  Future<bool> eliminarActividad({
    required int inspeccionId,
    required int inspeccionActividadId,
    required String notas,
    bool silencioso = false,
  }) async {
    try {
      if (!silencioso) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }

      final exito = await InspeccionesApiService.eliminarActividad(
        inspeccionActividadId: inspeccionActividadId,
        notas: notas,
      );

      if (exito) {
        // Recargar lista y detalle (siempre silencioso para evitar parpadeo)
        await cargarInspecciones(mantenerPagina: true);
        if (_inspeccionSeleccionada?.id == inspeccionId) {
          await cargarInspeccion(inspeccionId, silencioso: true);
        }
      }
      
      if (!silencioso) {
        _isLoading = false;
        notifyListeners();
      }
      return exito;
    } catch (e) {
      debugPrint('ERROR EN ELIMINAR ACTIVIDAD: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Autorizar actividad
  Future<bool> autorizarActividad({
    required int inspeccionActividadId,
    required bool autorizada,
    String? notas,
  }) async {
    try {
      final exito = await InspeccionesApiService.autorizarActividad(
        inspeccionActividadId: inspeccionActividadId,
        autorizada: autorizada,
        notas: notas,
      );

      if (exito && _inspeccionSeleccionada != null) {
        // Recargar detalle para actualizar estado de actividad (SILENCIOSO para evitar parpadeo)
        await cargarInspeccion(_inspeccionSeleccionada!.id!, silencioso: true);
      }

      return exito;
    } catch (e) {
      debugPrint('ERROR EN AUTORIZAR ACTIVIDAD: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Crear servicio desde actividad
  Future<Map<String, dynamic>?> crearServicioDesdeActividad({
    required int inspeccionActividadId,
    required int autorizadoPor,
    String? ordenCliente,
    String? tipoMantenimiento,
    String? centroCosto,
    required int estadoId,
    int? clienteId,
    String? nota,
  }) async {
    try {
      final resultado = await InspeccionesApiService.crearServicioDesdeActividad(
        inspeccionActividadId: inspeccionActividadId,
        autorizadoPor: autorizadoPor,
        ordenCliente: ordenCliente,
        tipoMantenimiento: tipoMantenimiento,
        centroCosto: centroCosto,
        estadoId: estadoId,
        clienteId: clienteId,
        nota: nota,
      );

      if (_inspeccionSeleccionada != null) {
        // Recargar detalle para actualizar estado de actividad
        await cargarInspeccion(_inspeccionSeleccionada!.id!);
      }

      return resultado;
    } catch (e) {
      debugPrint('ERROR EN CREAR SERVICIO DESDE ACTIVIDAD: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Aplicar filtros
  void aplicarFiltros({
    String? buscar,
    String? estado,
    String? sitio,
    int? equipoId,
    String? fechaDesde,
    String? fechaHasta,
  }) {
    _buscar = buscar;
    _estadoFiltro = estado;
    _sitioFiltro = sitio;
    _equipoIdFiltro = equipoId;
    _fechaDesde = fechaDesde;
    _fechaHasta = fechaHasta;

    cargarInspecciones();
  }

  /// Limpiar filtros
  void limpiarFiltros() {
    _buscar = null;
    _estadoFiltro = null;
    _sitioFiltro = null;
    _equipoIdFiltro = null;
    _fechaDesde = null;
    _fechaHasta = null;

    cargarInspecciones();
  }

  /// Navegar a página siguiente
  void paginaSiguiente() {
    if (tieneSiguiente) {
      _paginaActual++;
      cargarInspecciones(mantenerPagina: true);
    }
  }

  /// Navegar a página anterior
  void paginaAnterior() {
    if (tieneAnterior) {
      _paginaActual--;
      cargarInspecciones(mantenerPagina: true);
    }
  }

  /// Ir a página específica
  void irAPagina(int pagina) {
    if (pagina >= 1 && pagina <= _totalPaginas) {
      _paginaActual = pagina;
      cargarInspecciones(mantenerPagina: true);
    }
  }

  /// Limpiar selección
  void limpiarSeleccion() {
    _inspeccionSeleccionada = null;
    notifyListeners();
  }

  /// Limpiar error
  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}
