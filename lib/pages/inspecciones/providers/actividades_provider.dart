import 'package:flutter/foundation.dart';
import '../models/actividad_estandar_model.dart';
import '../services/actividades_estandar_api_service.dart';

class ActividadesProvider with ChangeNotifier {
  List<ActividadEstandarModel> _actividades = [];
  bool _isLoading = false;
  String? _error;

  List<ActividadEstandarModel> get actividades => _actividades;
  List<ActividadEstandarModel> get actividadesActivas => _actividades.where((a) => a.activo).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> cargarActividades({bool soloActivas = true}) async {
    _isLoading = true;
    _error = null;
    // notifyListeners(); // Evitar rebuilds innecesarios si se llama en init

    try {
      _actividades = await ActividadesEstandarApiService.listarActividades(
        activo: soloActivas ? true : null,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  ActividadEstandarModel? obtenerPorId(int id) {
    try {
      return _actividades.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
