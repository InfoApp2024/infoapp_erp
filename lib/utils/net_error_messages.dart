import 'package:flutter/material.dart';
import 'dart:async';
import 'package:infoapp/main.dart'; // ✅ Importar MyApp para acceder a messengerKey

/// Utilidad para convertir excepciones y textos crudos en mensajes amigables.
class NetErrorMessages {
  static String from(Object e, {String? contexto}) {
    final raw = e.toString();
    final s = raw.toLowerCase();

    String base;
    if (s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('no address associated')) {
      base = 'Sin conexi\u00f3n a internet o dominio inaccesible.';
    } else if (s.contains('timeout')) {
      base = 'Tiempo de espera agotado al conectar con el servidor.';
    } else if (s.contains('http 401') || s.contains('autenticaci\u00f3n')) {
      base = 'Sesi\u00f3n expirada o credenciales inv\u00e1lidas. Inicie sesi\u00f3n nuevamente.';
    } else if (s.contains('http') && s.contains('error')) {
      base = 'Error del servidor. Intente de nuevo m\u00e1s tarde.';
    } else if (e is TimeoutException) {
      base = 'Tiempo de espera agotado al conectar con el servidor.';
    } else {
      base = 'Ocurri\u00f3 un problema de conexi\u00f3n.';
    }

    final detalleBreve = _resumir(raw);
    if (contexto != null && contexto.isNotEmpty) {
      return '$base\nNo se pudo $contexto. $detalleBreve';
    }
    return '$base\n$detalleBreve';
  }

  static String _resumir(String raw) {
    // Evita mostrar URLs largas o trazas completas.
    final maxLen = 140;
    final limpio = raw.replaceAll(RegExp(r'https?://[^\s]+'), '[URL]');
    return (limpio.length > maxLen)
        ? '${limpio.substring(0, maxLen)}…'
        : limpio;
  }

  /// Muestra un SnackBar con estilo consistente.
  /// - `success=true` usa verde; en caso contrario usa rojo.
  static void showMessage(
    BuildContext? context,
    String message, {
    bool success = false,
  }) {
    final color = success ? Colors.green.shade600 : Colors.red.shade600;
    MyApp.showSnackBar(
      message,
      backgroundColor: color,
      duration: const Duration(seconds: 5),
    );
  }

  /// Extrae y muestra un error de red limpio en rojo.
  static void showNetError(
    BuildContext? context,
    Object e, {
    String? contexto,
  }) {
    final msg = NetErrorMessages.from(e, contexto: contexto);
    showMessage(context, msg, success: false);
  }

  /// Mensaje corto y controlado para módulos sin soporte offline.
  /// Úsalo cuando `!isOnline` y el módulo no tiene flujo offline.
  static void showOfflineModule(
    BuildContext? context, {
    String? nombreModulo,
  }) {
    final msg = 'Sin conexi\u00f3n';
    showMessage(context, msg, success: false);
  }
}
