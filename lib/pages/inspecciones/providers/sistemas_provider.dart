/// ============================================================================
/// ARCHIVO: sistemas_provider.dart
///
/// PROPÓSITO: Provider para gestión de catálogo de sistemas
/// ============================================================================
library;
// library;

import 'package:flutter/foundation.dart';
import '../models/sistema_model.dart';
import '../services/sistemas_api_service.dart';

class SistemasProvider with ChangeNotifier {
  // Estado
  List<SistemaModel> _sistemas = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<SistemaModel> get sistemas => _sistemas;
  List<SistemaModel> get sistemasActivos => _sistemas.where((s) => s.activo == true).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Cargar todos los sistemas
  Future<void> cargarSistemas({bool? soloActivos}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sistemas = await SistemasApiService.listarSistemas(
        activo: soloActivos,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crear nuevo sistema
  Future<bool> crearSistema({
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final nuevoSistema = await SistemasApiService.crearSistema(
        nombre: nombre,
        descripcion: descripcion,
        activo: activo,
      );

      _sistemas.add(nuevoSistema);
      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualizar sistema
  Future<bool> actualizarSistema({
    required int sistemaId,
    String? nombre,
    String? descripcion,
    bool? activo,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final exito = await SistemasApiService.actualizarSistema(
        sistemaId: sistemaId,
        nombre: nombre,
        descripcion: descripcion,
        activo: activo,
      );

      if (exito) {
        // Recargar lista
        await cargarSistemas();
      }

      _isLoading = false;
      notifyListeners();

      return exito;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Eliminar sistema
  Future<bool> eliminarSistema(int sistemaId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final exito = await SistemasApiService.eliminarSistema(sistemaId);

      if (exito) {
        _sistemas.removeWhere((s) => s.id == sistemaId);
      }

      _isLoading = false;
      notifyListeners();

      return exito;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Buscar sistema por ID
  SistemaModel? obtenerSistemaPorId(int id) {
    try {
      return _sistemas.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Limpiar error
  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}
