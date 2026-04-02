import 'package:flutter/foundation.dart';
import 'package:infoapp/pages/equipos/models/equipo_model.dart';
import 'package:infoapp/pages/equipos/services/equipos_api_service.dart';

class EquiposController extends ChangeNotifier {
  List<EquipoModel> _equipos = [];
  List<EquipoModel> get equipos => _equipos;

  bool _loading = false;
  bool get loading => _loading;

  String _query = '';
  String get query => _query;

  Future<void> cargarEquipos() async {
    _loading = true;
    notifyListeners();
    try {
      _equipos = await EquiposApiService.listarEquipos();
    } catch (_) {
      _equipos = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  List<EquipoModel> get equiposFiltrados {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _equipos;
    return _equipos.where((e) {
      return (e.nombre?.toLowerCase().contains(q) ?? false) ||
          (e.marca?.toLowerCase().contains(q) ?? false) ||
          (e.modelo?.toLowerCase().contains(q) ?? false) ||
          (e.codigo?.toLowerCase().contains(q) ?? false) ||
          (e.placa?.toLowerCase().contains(q) ?? false) ||
          (e.nombreEmpresa?.toLowerCase().contains(q) ?? false) ||
          (e.ciudad?.toLowerCase().contains(q) ?? false) ||
          (e.planta?.toLowerCase().contains(q) ?? false) ||
          (e.lineaProd?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<Map<String, dynamic>> crear(EquipoModel equipo) async {
    try {
      final result = await EquiposApiService.crearEquipo(equipo);
      if (result['success'] == true) {
        await cargarEquipos();
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> actualizar(EquipoModel equipo) async {
    try {
      final result = await EquiposApiService.actualizarEquipo(equipo);
      if (result['success'] == true) {
        await cargarEquipos();
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<bool> eliminar(int id) async {
    try {
      final ok = await EquiposApiService.eliminarEquipo(id: id);
      if (ok) {
        await cargarEquipos();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }
}
