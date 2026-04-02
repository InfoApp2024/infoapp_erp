// lib/services/user_service.dart
// Servicio para manejar los datos del usuario autenticado

import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();
  UserService._();

  // ✅ Obtener ID del usuario actual
  Future<int?> getUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('usuario_id');
  }

  // ✅ Obtener datos completos del usuario
  Future<Map<String, dynamic>?> getUsuarioCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('usuario_id');

    if (id == null) return null;

    return {
      'id': id,
      'usuario': prefs.getString('usuario_nombre'),
      'rol': prefs.getString('usuario_rol'),
      'estado': prefs.getString('usuario_estado'),
      'nombre_completo': prefs.getString('nombre_completo'),
      'correo': prefs.getString('correo'),
      'nit': prefs.getString('nit'),
      'login_timestamp': prefs.getString('login_timestamp'),
    };
  }

  // ✅ Verificar si hay usuario logueado
  Future<bool> isLoggedIn() async {
    final id = await getUsuarioId();
    return id != null;
  }

  // ✅ Obtener nombre del usuario
  Future<String?> getNombreUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('usuario_nombre');
  }

  // ✅ Obtener rol del usuario
  Future<String?> getRolUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('usuario_rol');
  }

  // ✅ Limpiar datos del usuario (logout)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_id');
    await prefs.remove('usuario_nombre');
    await prefs.remove('usuario_rol');
    await prefs.remove('usuario_estado');
    await prefs.remove('nombre_completo');
    await prefs.remove('correo');
    await prefs.remove('nit');
    await prefs.remove('login_timestamp');
  }

  // ✅ Verificar si el login ha expirado (opcional)
  Future<bool> isLoginExpired({int horasExpiracion = 24}) async {
    final prefs = await SharedPreferences.getInstance();
    final loginTimestamp = prefs.getString('login_timestamp');

    if (loginTimestamp == null) return true;

    try {
      final loginDate = DateTime.parse(loginTimestamp);
      final now = DateTime.now();
      final difference = now.difference(loginDate);

      return difference.inHours >= horasExpiracion;
    } catch (e) {
      return true; // Si hay error, considerar expirado
    }
  }

  // ✅ Debug - Imprimir datos del usuario
  Future<void> printUserData() async {
    final usuario = await getUsuarioCompleto();
//     print('=== DATOS DEL USUARIO ===');
//     print('Usuario: ${usuario ?? 'No logueado'}');
//     print('========================');
  }
}
