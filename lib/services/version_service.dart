import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:infoapp/core/version/app_version.dart'; // 🆕 Importar constante grabada en el código

class VersionService {
  /// Obtiene la versión actual de la aplicación (definida en pubspec.yaml)
  static Future<String> getCurrentVersion() async {
    // 🆕 En Web, usamos la constante grabada en el código binario.
    // Esto evita que PackageInfo lea version.json del servidor (que siempre es el último).
    if (kIsWeb) {
      return kAppVersion;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;

    if (buildNumber.isEmpty) {
      return version;
    }
    // Si la versión ya contiene el build number (puede pasar en algunas plataformas), no lo agregamos de nuevo
    if (version.contains('+')) {
      return version;
    }
    return "$version+$buildNumber";
  }

  /// Consulta el archivo version.json en el servidor
  /// Usa cabeceras explícitas de no-cache para evitar que el Service Worker sirva la versión vieja
  static Future<String?> getServerVersion() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('version.json?t=$ts'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['version'] as String?;
      }
    } catch (e) {
      debugPrint('Error al obtener la versión del servidor: $e');
    }
    return null;
  }

  /// Compara la versión local con la del servidor
  /// Retorna true SI Y SOLO SI la versión del servidor es MAYOR que la local
  static Future<bool> isUpdateAvailable() async {
    // Solo aplica para Web en este contexto de Cache Busting
    if (!kIsWeb) return false;

    final currentVersionStr = await getCurrentVersion();
    final serverVersionStr = await getServerVersion();

    if (serverVersionStr == null) {
      debugPrint(
        '⚠️ No se pudo obtener la versión del servidor (version.json).',
      );
      return false;
    }

    debugPrint('🔍 Verificando Actualización:');
    debugPrint('   - Local (App):    $currentVersionStr');
    debugPrint('   - Servidor (JSON): $serverVersionStr');

    try {
      final current = _parseVersion(currentVersionStr);
      final server = _parseVersion(serverVersionStr);

      debugPrint('   - Pesos calculados: Local=$current, Server=$server');

      if (server > current) {
        debugPrint(
          '🚀 ¡Nueva versión detectada! Mostrando botón de actualización.',
        );
        return true;
      } else if (server < current) {
        debugPrint(
          'ℹ️ La versión del servidor es anterior a la local (posible desarrollo).',
        );
      } else {
        debugPrint(
          '✅ La aplicación ya está actualizada o las versiones coinciden.',
        );
      }
    } catch (e) {
      debugPrint('Error comparando versiones: $e');
      // Fallback: Si el parseo falla, comparamos strings directamente
      return currentVersionStr.split('+')[0] != serverVersionStr.split('+')[0];
    }

    return false;
  }

  /// Helper para convertir "1.0.1+1" o "1.0.1" en un valor comparable
  static int _parseVersion(String version) {
    try {
      final parts = version.split('+');
      final semVer = parts[0];
      final buildNum = parts.length > 1 ? parts[1] : '0';

      final mainParts = semVer.split('.');

      int major = mainParts.isNotEmpty ? (int.tryParse(mainParts[0]) ?? 0) : 0;
      int minor = mainParts.length > 1 ? (int.tryParse(mainParts[1]) ?? 0) : 0;
      int patch = mainParts.length > 2 ? (int.tryParse(mainParts[2]) ?? 0) : 0;
      int build = int.tryParse(buildNum) ?? 0;

      return (major * 1000000) + (minor * 10000) + (patch * 100) + build;
    } catch (e) {
      debugPrint('Error parseando versión $version: $e');
      return 0;
    }
  }

  /// Limpia el caché de assets del Service Worker y recarga la aplicación.
  ///
  /// ✅ NO borra localStorage (preserva sesión, config del servidor, etc.)
  /// Solo limpia el caché del Service Worker para forzar la descarga de
  /// los nuevos archivos del build sin perder la sesión del usuario.
  static Future<void> clearCacheAndReload() async {
    if (!kIsWeb) return;

    debugPrint('🧹 Iniciando limpieza de caché de assets...');

    // 🛡️ Guardia anti-loop: si ya se recargó hace menos de 15 segundos, no hacer otra recarga
    final lastReloadStr = html.window.sessionStorage['last_cache_reload'];
    if (lastReloadStr != null) {
      final lastReload = int.tryParse(lastReloadStr) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastReload;
      if (elapsed < 15000) {
        debugPrint('⚠️ Recarga reciente detectada (${elapsed}ms), abortando para evitar loop.');
        return;
      }
    }

    // Marcar timestamp de esta recarga ANTES de limpiar (para el anti-loop post-reload)
    html.window.sessionStorage['last_cache_reload'] =
        '${DateTime.now().millisecondsSinceEpoch}';

    // ✅ Solo limpiar el caché de assets (Service Worker + Cache API)
    // NO borrar localStorage — preserva sesión del usuario y config del servidor
    try {
      _injectCacheClearScript();
      await Future.delayed(const Duration(milliseconds: 1500));
      debugPrint('   ✅ Service Worker y Cache API limpiados');
    } catch (e) {
      debugPrint('   ⚠️ Error al limpiar SW/Cache API: $e (continuando recarga...)');
    }

    // Recargar con query param único para forzar bypass del CDN/proxy
    debugPrint('   🔄 Recargando aplicación...');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final currentHref = html.window.location.href;
    final baseHref = currentHref.split('?')[0];
    html.window.location.assign('$baseHref?v=$ts');
  }

  /// Inyecta y ejecuta un script JS que:
  /// - Desregistra todos los Service Workers
  /// - Borra todos los caches del Cache API (flutter_service_worker etc.)
  static void _injectCacheClearScript() {
    const script = '''
      (async function() {
        try {
          // Desregistrar todos los Service Workers
          if ('serviceWorker' in navigator) {
            const registrations = await navigator.serviceWorker.getRegistrations();
            for (const registration of registrations) {
              await registration.unregister();
              console.log('[Cache Clear] Service Worker desregistrado:', registration.scope);
            }
          }

          // Borrar todos los caches del Cache API
          if ('caches' in window) {
            const cacheNames = await caches.keys();
            for (const cacheName of cacheNames) {
              await caches.delete(cacheName);
              console.log('[Cache Clear] Cache borrado:', cacheName);
            }
          }

          console.log('[Cache Clear] ✅ Limpieza completa de Service Worker y Cache API finalizada.');
        } catch(e) {
          console.warn('[Cache Clear] Error durante limpieza:', e);
        }
      })();
    ''';

    // Inyectar el script en el DOM para que el navegador lo ejecute
    final scriptEl = html.ScriptElement();
    scriptEl.text = script;
    html.document.head!.append(scriptEl);
    // Limpiar el elemento inyectado después de ejecutar
    Future.delayed(const Duration(milliseconds: 2000), () => scriptEl.remove());
  }
}
