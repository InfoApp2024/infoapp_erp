// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _tokenTypeKey = 'token_type';
  static const String _expiresAtKey = 'expires_at';
  static const String _userIdKey = 'usuario_id';
  static const String _userNameKey = 'usuario_nombre';
  static const String _userRolKey = 'usuario_rol';
  static const String _userEstadoKey = 'usuario_estado';
  static const String _nombreCompletoKey = 'nombre_completo';
  static const String _correoKey = 'correo';
  static const String _nitKey = 'nit';
  static const String _loginTimestampKey = 'login_timestamp';
  static const String _lastActivityKey = 'last_activity_timestamp';
  static const String _loginRouteActiveKey = 'login_route_active';
  static const String _userFotoKey = 'url_foto';
  static const String _funcionarioIdKey = 'funcionario_id';
  static const String _clienteIdKey = 'cliente_id';
  static const String _esAuditorKey = 'es_auditor';
  static const String _canEditClosedOpsKey = 'can_edit_closed_ops';

  /// Guardar token JWT y datos del usuario después del login
  static Future<void> saveAuthData({
    required String token,
    required String tokenType,
    required String expiresAt,
    required Map<String, dynamic> userData,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar datos del token
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_tokenTypeKey, tokenType);
    await prefs.setString(_expiresAtKey, expiresAt);

    // Guardar datos del usuario
    await prefs.setInt(_userIdKey, userData['id'] ?? 0);
    await prefs.setString(_userNameKey, userData['usuario'] ?? '');
    await prefs.setString(_userRolKey, userData['rol'] ?? '');
    await prefs.setString(_userEstadoKey, userData['estado'] ?? 'activo');

    // Guardar datos adicionales si existen
    if (userData['nombre_completo'] != null) {
      await prefs.setString(_nombreCompletoKey, userData['nombre_completo']);
    }
    if (userData['correo'] != null) {
      await prefs.setString(_correoKey, userData['correo']);
    }
    if (userData['nit'] != null) {
      await prefs.setString(_nitKey, userData['nit']);
    }
    if (userData['url_foto'] != null) {
      await prefs.setString(_userFotoKey, userData['url_foto']);
    } else {
      await prefs.remove(_userFotoKey);
    }
    if (userData['funcionario_id'] != null) {
      final val = userData['funcionario_id'];
      final intId = val is int ? val : int.tryParse(val.toString());
      if (intId != null) {
        await prefs.setInt(_funcionarioIdKey, intId);
      }
    } else {
      await prefs.remove(_funcionarioIdKey);
    }
    if (userData['cliente_id'] != null) {
      final val = userData['cliente_id'];
      final intId = val is int ? val : int.tryParse(val.toString());
      if (intId != null) {
        await prefs.setInt(_clienteIdKey, intId);
      }
    } else {
      await prefs.remove(_clienteIdKey);
    }

    // Guardar flag de auditor
    if (userData['es_auditor'] != null) {
      final val = userData['es_auditor'];
      final esAuditor = (val == 1 || val == '1' || val == true);
      await prefs.setBool(_esAuditorKey, esAuditor);
    } else {
      await prefs.remove(_esAuditorKey);
    }

    // Guardar flag de editar operaciones cerradas
    if (userData['can_edit_closed_ops'] != null) {
      final val = userData['can_edit_closed_ops'];
      final canEdit = (val == 1 || val == '1' || val == true);
      await prefs.setBool(_canEditClosedOpsKey, canEdit);
    } else {
      await prefs.remove(_canEditClosedOpsKey);
    }

    // Guardar timestamp del login
    await prefs.setString(_loginTimestampKey, DateTime.now().toIso8601String());
    await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  /// Obtener token JWT guardado
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Obtener token con el prefijo Bearer
  static Future<String?> getBearerToken() async {
    final token = await getToken();
    if (token != null) {
      return 'Bearer $token';
    }
    return null;
  }

  /// Verificar si el token está expirado
  static Future<bool> isTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAtString = prefs.getString(_expiresAtKey);

    if (expiresAtString == null) return true;

    try {
      final expiresAt = DateTime.parse(expiresAtString);
      return DateTime.now().isAfter(expiresAt);
    } catch (e) {
      return true;
    }
  }

  /// Verificar si el usuario está autenticado
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;

    final isExpired = await isTokenExpired();
    return !isExpired;
  }

  /// Verificar si hubo un login reciente dentro de las últimas [hours] horas
  static Future<bool> hadRecentLogin({int hours = 24}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_loginTimestampKey);
    if (ts == null) return false;
    try {
      final dt = DateTime.parse(ts);
      final diff = DateTime.now().difference(dt);
      return diff.inHours < hours;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canEditClosedOps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_canEditClosedOpsKey) ?? false;
  }

  static Future<bool> isAuditor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_esAuditorKey) ?? false;
  }

  static Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_lastActivityKey);
    if (ts == null) return null;
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isInactiveFor(Duration timeout) async {
    final last = await getLastActivity();
    if (last == null) return false;
    return DateTime.now().difference(last) >= timeout;
  }

  /// Bandera: ¿está activa la pantalla de login? (para evitar auto-login en recarga)
  static Future<void> setLoginRouteActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginRouteActiveKey, active);
  }

  static Future<bool> isLoginRouteActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loginRouteActiveKey) ?? false;
  }

  /// Obtener datos del usuario guardados
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getInt(_userIdKey);
    final usuario = prefs.getString(_userNameKey);
    final rol = prefs.getString(_userRolKey);
    final funcionarioId = prefs.getInt(_funcionarioIdKey);
    final clienteId = prefs.getInt(_clienteIdKey);
    final esAuditor = prefs.getBool(_esAuditorKey) ?? false;
    final canEditClosedOps = prefs.getBool(_canEditClosedOpsKey) ?? false;

    if (id == null || usuario == null || rol == null) return null;

    return {
      'id': id,
      'usuario': usuario,
      'rol': rol,
      'estado': prefs.getString(_userEstadoKey) ?? 'activo',
      'nombre_completo': prefs.getString(_nombreCompletoKey),
      'correo': prefs.getString(_correoKey),
      'nit': prefs.getString(_nitKey),
      'url_foto': prefs.getString(_userFotoKey),
      'funcionario_id': funcionarioId,
      'cliente_id': clienteId,
      'es_auditor': esAuditor ? 1 : 0,
      'can_edit_closed_ops': canEditClosedOps,
      'login_timestamp': prefs.getString(_loginTimestampKey),
    };
  }

  /// Refrescar datos del usuario desde el servidor
  static Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      final token = await getBearerToken();
      if (token == null) return null;

      // Importar http si no está (asumiendo que está disponible vía ServiciosApiService o similar)
      // Pero AuthService suele ser de bajo nivel. Usaremos un approach directo.
      // Si hay un ApiClient global se podría usar.
      // Por ahora, simulamos la actualización si el endpoint perfil.php es llamado.
      // WORKAROUND: Como AuthService no tiene inyectado el cliente http de la app usualmente,
      // la lógica de refresco se puede disparar desde el controlador que sí lo tenga.
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Limpiar todos los datos de autenticación (logout)
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenTypeKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userRolKey);
    await prefs.remove(_userEstadoKey);
    await prefs.remove(_nombreCompletoKey);
    await prefs.remove(_correoKey);
    await prefs.remove(_nitKey);
    await prefs.remove(_loginTimestampKey);
    await prefs.remove(_lastActivityKey);
    await prefs.remove(_loginRouteActiveKey);
    await prefs.remove(_funcionarioIdKey);
    await prefs.remove(_clienteIdKey);
    await prefs.remove(_esAuditorKey);
    await prefs.remove(_canEditClosedOpsKey);
    await prefs.remove(_userFotoKey);
    await prefs.remove('servicios_cache_list_v1'); // Limpiar caché de servicios
  }

  /// Obtener información del token para debug
  static Future<Map<String, dynamic>?> getTokenInfo() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'has_token': prefs.getString(_tokenKey) != null,
      'token_type': prefs.getString(_tokenTypeKey),
      'expires_at': prefs.getString(_expiresAtKey),
      'is_expired': await isTokenExpired(),
      'login_timestamp': prefs.getString(_loginTimestampKey),
    };
  }
}
