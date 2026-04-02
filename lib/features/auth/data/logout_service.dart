// lib/services/logout_service.dart
// SERVICIO PARA MANEJAR EL LOGOUT

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/presentation/state/auth_controller.dart';

class LogoutService {
  static String get _baseUrl => ServerConfig.instance.apiRoot();

  /// Cerrar sesión en el servidor
  static Future<Map<String, dynamic>> logout({
    required String nombreUsuario,
    String? idRegistro,
  }) async {
    try {
      final url = '$_baseUrl/login/logout.php';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'NOMBRE_USER': nombreUsuario,
          'ID_REGISTRO': idRegistro ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        return {
          'success': false,
          'message': 'Error de conexión: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de red: ${e.toString()}'};
    }
  }

  /// Mostrar dialog de confirmación antes del logout
  static Future<bool> showLogoutDialog(BuildContext context) async {
    final primaryColor = Theme.of(context).primaryColor;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: primaryColor,
                  ), // Usar color del branding
                  const SizedBox(width: 8),
                  const Text('Cerrar Sesión'),
                ],
              ),
              content: const Text(
                '¿Estás seguro que deseas cerrar tu sesión?\n\nPerderás cualquier trabajo no guardado.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, // Usar color del branding
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Ejecutar logout completo con confirmación
  static Future<void> performLogout({
    required BuildContext context,
    required String nombreUsuario,
    String? idRegistro,
    VoidCallback? onLogoutComplete,
  }) async {
    // Mostrar dialog de confirmación
    final shouldLogout = await showLogoutDialog(context);

    if (!shouldLogout) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cerrando sesión...'),
                  ],
                ),
              ),
            ),
          ),
    );

    try {
      // Llamar al servicio de logout
      final result = await logout(
        nombreUsuario: nombreUsuario,
        idRegistro: idRegistro,
      );

      // Cerrar dialog de loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (result['success']) {
        // ✅ FIX: Usar AuthController reactivo en lugar de navegación explícita.
        // Navigator.pushNamedAndRemoveUntil('/login') agregaba una entrada al historial
        // del navegador, causando que el botón ← devolviera al login incluso con sesión activa.
        if (context.mounted) {
          _showSuccessMessage(context, result['message']);
          // Ejecutar callback si existe
          onLogoutComplete?.call();
          // El AuthController notifica a _buildMainApp() que muestre el login
          context.read<AuthController>().logout();
        }
      } else {
        // Error en logout
        if (context.mounted) {
          _showErrorMessage(context, result['message']);
        }
      }
    } catch (e) {
      // Cerrar dialog de loading si está abierto
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorMessage(context, 'Error inesperado: ${e.toString()}');
      }
    }
  }

  /// Logout forzado (sin confirmación del servidor)
  /// ✅ FIX: Usa AuthController reactivo para no agregar entradas al historial del navegador.
  static Future<void> forceLogout({
    required BuildContext context,
    String? message,
  }) async {
    _showWarningMessage(context, message ?? 'Sesión cerrada automáticamente');

    if (context.mounted) {
      // AuthController notifica a _buildMainApp() que muestre el login reactivamente
      context.read<AuthController>().logout();
    }
  }

  // Métodos privados para mostrar mensajes
  static void _showSuccessMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void _showErrorMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void _showWarningMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
