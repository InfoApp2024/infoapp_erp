import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/features/auth/data/permissions_service.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/core/env/server_config.dart';

class AuthController extends ChangeNotifier {
  bool obscurePassword = true;
  bool isLoading = false;

  // Propiedades reactivas para la sesión
  bool _isAuthenticated = false;
  String? _nombreUsuario;
  String? _rol;

  bool get isAuthenticated => _isAuthenticated;
  String? get nombreUsuario => _nombreUsuario;
  String? get rol => _rol;

  void toggleObscure() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void setLoading(bool value) {
    if (isLoading != value) {
      isLoading = value;
      notifyListeners();
    }
  }

  /// Inicializar el estado de autenticación desde el almacenamiento local
  Future<void> checkAuthStatus() async {
    final authenticated = await AuthService.isAuthenticated();
    if (authenticated) {
      final userData = await AuthService.getUserData();
      _isAuthenticated = true;
      _nombreUsuario = userData?['usuario'];
      _rol = userData?['rol'];
    } else {
      _isAuthenticated = false;
      _nombreUsuario = null;
      _rol = null;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> loginUsuario(String usuario, String password) async {
    if (isLoading) {
      return {'success': false, 'message': 'busy'};
    }
    setLoading(true);
    try {
      final String loginBase = ServerConfig.instance.baseUrlFor('login');
      final List<String> urlsToTry = [
        '$loginBase/login.php',
      ];

      final requestBody = {'NOMBRE_USER': usuario, 'CONTRASE\u00d1A': password};

      http.Response? successResponse;
      String? workingUrl;

      for (int i = 0; i < urlsToTry.length; i++) {
        final url = urlsToTry[i];
        try {
          final response = await http
              .post(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json; charset=utf-8',
                  'Accept': 'application/json',
                },
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            successResponse = response;
            workingUrl = url;
            break;
          }
        } catch (_) {}
      }

      if (successResponse == null || workingUrl == null) {
        throw Exception('No se pudo conectar al servidor');
      }

      final result = jsonDecode(successResponse.body);
      if (result['success'] != true) {
        final String errorMessage = result['message']?.toString().toLowerCase() ?? '';
        final String debugMessage = result['debug']?.toString().toLowerCase() ?? '';
        
        if (errorMessage.contains('cliente inactivo') || 
            debugMessage.contains('cliente inactivo')) {
          throw Exception('El servicio actualmente est\u00e1 fuera de servicio, contacte al administrador');
        }
        throw Exception(result['message'] ?? 'Usuario o contraseña no válidos');
      }

      if (result['token'] == null) {
        throw Exception('Token inv\u00e1lido');
      }

      final String token = result['token'];
      final String tokenType = result['token_type'] ?? 'Bearer';
      final String expiresAt = result['expires_at'] ??
          DateTime.now()
              .add(Duration(seconds: result['expires_in'] ?? 86400))
              .toIso8601String();

      final userData = result['data'];
      if (userData == null) {
        throw Exception('Datos de usuario inv\u00e1lidos');
      }

      final String nombreUsuario = userData['usuario'] ?? 'Usuario';
      final String rol = userData['rol'] ?? 'Sin rol';

      await AuthService.saveAuthData(
        token: token,
        tokenType: tokenType,
        expiresAt: expiresAt,
        userData: {
          'id': userData['id'] ?? 0,
          'usuario': userData['usuario'] ?? '',
          'rol': userData['rol'] ?? '',
          'estado': userData['estado'] ?? 'activo',
          'nombre_completo': userData['nombre_completo'],
          'correo': userData['correo'],
          'nit': userData['nit'],
          'url_foto': userData['url_foto'],
          'funcionario_id': userData['funcionario_id'],
          'cliente_id': userData['cliente_id'],
          'working_url': workingUrl,
        },
      );

      try {
        final int userId = (userData['id'] ?? 0) is int
            ? (userData['id'] ?? 0)
            : int.tryParse(userData['id']?.toString() ?? '0') ?? 0;
        await PermissionStore.instance.loadFromPrefs(userId);
        final perms = await PermissionsService.listarPermisos(userId: userId);
        await PermissionStore.instance.setForUser(userId, perms);
      } catch (_) {}

      // Actualizar estado reactivo
      _isAuthenticated = true;
      _nombreUsuario = nombreUsuario;
      _rol = rol;
      notifyListeners();

      return {
        'success': true,
        'usuario': nombreUsuario,
        'rol': rol,
      };
    } catch (e) {
      await AuthService.clearAuthData();
      _isAuthenticated = false;
      _nombreUsuario = null;
      _rol = null;
      notifyListeners();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// Cerrar sesión y limpiar datos
  Future<void> logout() async {
    await AuthService.clearAuthData();
    _isAuthenticated = false;
    _nombreUsuario = null;
    _rol = null;
    notifyListeners();
  }
}
