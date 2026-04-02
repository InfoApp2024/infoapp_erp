import 'package:flutter/material.dart';
import '../models/actividad_estandar_model.dart';
import 'actividades_api_service.dart';


class ActividadesService extends ChangeNotifier {
  List<ActividadEstandarModel> _actividades = [];
  List<ActividadEstandarModel> _actividadesFiltradas = [];
  bool _isLoading = false;
  String _error = '';
  String _busqueda = '';
  bool? _filtroActivo;

  // Getters
  List<ActividadEstandarModel> get actividades => _actividadesFiltradas;
  List<ActividadEstandarModel> get todasLasActividades => _actividades;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get busqueda => _busqueda;
  bool? get filtroActivo => _filtroActivo;

  // Cache para evitar llamadas repetidas
  DateTime? _ultimaCarga;
  static const Duration _cacheDuration = Duration(minutes: 5);
  bool? _ultimoActivo; // Para distinguir cache por estado

  /// Cargar actividades con cache
  Future<void> cargarActividades({bool forceRefresh = false, bool? activo = true}) async {
    // Verificar cache
    if (!forceRefresh &&
        _ultimaCarga != null &&
        DateTime.now().difference(_ultimaCarga!) < _cacheDuration &&
        _actividades.isNotEmpty &&
        _ultimoActivo == activo) {
      _aplicarFiltros();
      return;
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _actividades = await ActividadesApiService.listarActividades(
        activo: activo, // Solo cargar activas por defecto
      );
      _ultimaCarga = DateTime.now();
      _ultimoActivo = activo;
      _aplicarFiltros();
      _error = '';
    } catch (e) {
      _error = e.toString();
//       print('❌ Error cargando actividades: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Buscar actividades
  void buscarActividades(String query) {
    _busqueda = query.toLowerCase();
    _aplicarFiltros();
    notifyListeners();
  }

  /// Filtrar por estado activo
  void filtrarPorEstado(bool? activo) {
    _filtroActivo = activo;
    _aplicarFiltros();
    notifyListeners();
  }

  /// Aplicar filtros localmente
  void _aplicarFiltros() {
    _actividadesFiltradas =
        _actividades.where((actividad) {
          // Filtro por búsqueda
          if (_busqueda.isNotEmpty) {
            if (!actividad.actividad.toLowerCase().contains(_busqueda)) {
              return false;
            }
          }

          // Filtro por estado
          if (_filtroActivo != null && actividad.activo != _filtroActivo) {
            return false;
          }

          return true;
        }).toList();

    // Ordenar alfabéticamente
    _actividadesFiltradas.sort(
      (a, b) => a.actividad.toLowerCase().compareTo(b.actividad.toLowerCase()),
    );
  }

  /// Crear nueva actividad
  Future<ActividadEstandarModel?> crearActividad(
    String nombreActividad, {
    double cantHora = 0.0,
    int numTecnicos = 1,
    int? sistemaId,
  }) async {
    try {
      // ✅ LOGS DE DEBUG
//       print('🚀 DEBUG SERVICE:');
//       print('📩 Service recibió: "$nombreActividad"');
//       print('📩 Longitud: ${nombreActividad.length}');
//       print('📩 Es vacío: ${nombreActividad.isEmpty}');

      final nuevaActividad = ActividadEstandarModel(
        actividad: nombreActividad.trim(),
        activo: true,
        cantHora: cantHora,
        numTecnicos: numTecnicos,
        sistemaId: sistemaId,
      );

      // ✅ LOG DEL MODELO
//       print('📦 Modelo creado:');
//       print('   - actividad: "${nuevaActividad.actividad}"');
//       - activo: ${nuevaActividad.activo}');
//       - toJson: ${nuevaActividad.toJson()}');

      final actividadCreada = await ActividadesApiService.crearActividad(
        nuevaActividad,
      );

      // Agregar a la lista local
      _actividades.add(actividadCreada);
      _aplicarFiltros();
      notifyListeners();

      return actividadCreada;
    } catch (e) {
//       print('❌ Error creando actividad: $e');
      rethrow;
    }
  }

  /// Actualizar actividad
  Future<void> actualizarActividad(ActividadEstandarModel actividad) async {
    try {
      final actividadActualizada =
          await ActividadesApiService.actualizarActividad(actividad);

      // Actualizar en la lista local
      final index = _actividades.indexWhere((a) => a.id == actividad.id);
      if (index != -1) {
        _actividades[index] = actividadActualizada;
        _aplicarFiltros();
        notifyListeners();
      }
    } catch (e) {
//       print('❌ Error actualizando actividad: $e');
      rethrow;
    }
  }

  /// Eliminar actividad
  Future<void> eliminarActividad(int id) async {
    try {
      await ActividadesApiService.eliminarActividad(id);

      // Eliminar de la lista local
      _actividades.removeWhere((a) => a.id == id);
      _aplicarFiltros();
      notifyListeners();
    } catch (e) {
//       print('❌ Error eliminando actividad: $e');
      rethrow;
    }
  }

  /// Limpiar cache
  void limpiarCache() {
    _ultimaCarga = null;
  }

  /// Obtener actividad por ID
  ActividadEstandarModel? obtenerActividadPorId(int? id) {
    if (id == null) return null;
    try {
      return _actividades.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }
}
