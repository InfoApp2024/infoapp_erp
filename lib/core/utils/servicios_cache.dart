import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:infoapp/pages/servicios/models/servicio_model.dart';

/// Utilidad simple para cachear la última lista de servicios
class ServiciosCache {
  static const _cacheKey = 'servicios_cache_list_v1';

  /// Guarda la lista completa de servicios en SharedPreferences
  static Future<void> saveList(List<ServicioModel> servicios) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = servicios.map((s) => s.toJson()).toList();
      final payload = {
        'ts': DateTime.now().toIso8601String(),
        'data': data,
      };
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (e) {
      // No interrumpir el flujo por errores de cache
      // print('ServiciosCache.saveList error: $e');
    }
  }

  /// Carga la lista cacheada; devuelve null si no hay datos
  static Future<List<ServicioModel>?> loadList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;

      final payload = jsonDecode(raw);
      final List<dynamic> data = payload['data'] ?? [];
      final servicios =
          data.map((json) => ServicioModel.fromJson(json)).toList();
      return servicios;
    } catch (e) {
      // print('ServiciosCache.loadList error: $e');
      return null;
    }
  }
}
