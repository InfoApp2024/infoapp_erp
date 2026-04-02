import 'package:flutter/foundation.dart';
import '../models/operacion_model.dart';
import '../services/servicio_operaciones_api_service.dart';

class OperacionesProvider extends ChangeNotifier {
  List<OperacionModel> _operaciones = [];
  bool _isLoading = false;
  int? _currentServicioId;

  List<OperacionModel> get operaciones => _operaciones;
  bool get isLoading => _isLoading;

  int get totalOperaciones => _operaciones.length;
  int get completadas => _operaciones.where((o) => o.estaFinalizada).length;
  String get resumenProgreso => '$completadas/$totalOperaciones Completadas';

  Future<void> cargarOperaciones(int servicioId) async {
    _currentServicioId = servicioId;
    _isLoading = true;
    notifyListeners();

    try {
      _operaciones = await ServicioOperacionesApiService.listarOperaciones(
        servicioId,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _lastError;
  String? get lastError => _lastError;

  Future<bool> agregarOperacion(
    String descripcion, {
    int? tecnicoId,
    int? actividadId,
    String? observaciones,
    DateTime? fechaInicio,
  }) async {
    if (_currentServicioId == null) return false;
    _lastError = null;

    final nueva = OperacionModel(
      servicioId: _currentServicioId!,
      descripcion: descripcion,
      tecnicoResponsableId: tecnicoId,
      actividadEstandarId: actividadId,
      observaciones: observaciones,
      fechaInicio: fechaInicio?.toIso8601String(),
    );

    final result = await ServicioOperacionesApiService.crearOperacion(nueva);
    final bool success = result['success'] == true;

    if (success) {
      await cargarOperaciones(_currentServicioId!);
    } else {
      _lastError = result['message'];
      notifyListeners();
    }
    return success;
  }

  Future<bool> finalizarOperacion(
    int id, {
    DateTime? fechaFin,
    String? observaciones,
  }) async {
    final Map<String, dynamic> data = {'finalizar': true};
    if (fechaFin != null) {
      data['fecha_fin'] = fechaFin.toIso8601String();
    }
    if (observaciones != null && observaciones.isNotEmpty) {
      data['observaciones_cierre'] = observaciones;
    }

    final result = await ServicioOperacionesApiService.actualizarOperacion(
      id,
      data,
    );
    final bool success = result['success'] == true;
    if (success && _currentServicioId != null) {
      await cargarOperaciones(_currentServicioId!);
    } else {
      _lastError = result['message'];
      notifyListeners();
    }
    return success;
  }

  Future<bool> actualizarOperacion(int id, Map<String, dynamic> data) async {
    final result = await ServicioOperacionesApiService.actualizarOperacion(
      id,
      data,
    );
    final bool success = result['success'] == true;
    if (success && _currentServicioId != null) {
      await cargarOperaciones(_currentServicioId!);
    } else {
      _lastError = result['message'];
      notifyListeners();
    }
    return success;
  }

  Future<bool> eliminarOperacion(int id) async {
    final result = await ServicioOperacionesApiService.eliminarOperacion(id);
    final bool success = result['success'] == true;
    if (success && _currentServicioId != null) {
      await cargarOperaciones(_currentServicioId!);
    } else {
      _lastError = result['message'];
      notifyListeners();
    }
    return success;
  }
}
