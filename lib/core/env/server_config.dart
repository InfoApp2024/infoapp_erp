import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ServerConfig {
  static final ServerConfig instance = ServerConfig._();
  ServerConfig._();

  static const String _prefsKey = 'server_root';
  static const String _webDefaultRoot =
      'https://migracion-infoapp.novatechdevelopment.com';

  String? _currentRoot;

  // Raíces por defecto por módulo para mantener comportamiento actual
  static const Map<String, String> _moduleDefaultRoots = {
    'login': 'https://migracion-infoapp.novatechdevelopment.com',
    'staff': 'https://novatechdevelopment.com/migracion-infoapp',
    'inventory': 'https://migracion-infoapp.novatechdevelopment.com',
    'plantillas': 'https://migracion-infoapp.novatechdevelopment.com',
    'firma': 'https://migracion-infoapp.novatechdevelopment.com',
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currentRoot = prefs.getString(_prefsKey);
    if ((_currentRoot == null || _currentRoot!.isEmpty) && kIsWeb) {
      // ✅ NUEVO: En producción, usar el dominio donde está alojada la app
      if (kReleaseMode) {
        // Esto toma 'https://soporteinfoapp.novatechdevelopment.com' automáticamente
        _currentRoot = Uri.base.origin; 
      } else {
        // En debug (localhost), seguir usando el servidor de pruebas
        _currentRoot = _webDefaultRoot;
      }
      await prefs.setString(_prefsKey, _currentRoot!);
    }
    print('🔵 [ServerConfig] Loaded root: $_currentRoot');
    if (_currentRoot == null) {
      print('🔵 [ServerConfig] Using default module roots (Remote)');
    }
  }

  Future<void> setCurrentRoot(String root) async {
    final prefs = await SharedPreferences.getInstance();
    _currentRoot = root.trim().replaceAll(RegExp(r"/+$"), '');
    await prefs.setString(_prefsKey, _currentRoot!);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    _currentRoot = null;
    await prefs.remove(_prefsKey);
  }

  bool get hasCurrentRoot => _currentRoot != null && _currentRoot!.isNotEmpty;

  String? get currentRoot => _currentRoot;

  /// Obtiene el baseUrl para un módulo dado.
  /// Si hay raíz seleccionada, se usa esa; de lo contrario, el valor por defecto del módulo.
  String baseUrlFor(String module) {
    // ---------------------------------------------------------
    // 🔧 DESARROLLO LOCAL: Descomenta y ajusta esto para usar tu servidor local
    // if (kDebugMode && !kIsWeb) {
    //   // Android Emulator: 10.0.2.2 apunta al localhost del host
    //   // Ajusta 'infoapp/backend' según la carpeta en tu htdocs
    //   return "http://10.0.2.2/infoapp/backend/$module";
    // }
    // ---------------------------------------------------------

    if (hasCurrentRoot) {
      return "${_currentRoot!}/API_Infoapp/$module";
    }
    final root = _moduleDefaultRoots[module];
    if (root == null) {
      // Fallback genérico
      final genericRoot = _moduleDefaultRoots['login']!;
      return "$genericRoot/API_Infoapp/$module";
    }
    return "$root/API_Infoapp/$module";
  }

  /// Obtiene la raíz de la API (sin módulo): .../API_Infoapp
  String apiRoot() {
    if (hasCurrentRoot) {
      return "${_currentRoot!}/API_Infoapp";
    }
    // Usar la raíz del módulo login por defecto
    final genericRoot = _moduleDefaultRoots['login']!;
    return "$genericRoot/API_Infoapp";
  }
}
