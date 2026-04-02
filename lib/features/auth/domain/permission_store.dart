import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/core/utils/module_utils.dart';

/// Store simple y centralizada para consultar permisos en el frontend.
class PermissionStore {
  PermissionStore._();
  static final PermissionStore instance = PermissionStore._();

  Map<String, Set<String>> _perms = {};
  int? _userId;
  bool _isAdmin = false;
  static const String _prefsVersion = 'v2';
  bool _hydrated =
      false; // indica si se intentó cargar desde prefs o establecer permisos

  bool get isAdmin => _isAdmin;

  bool get isHydrated => _hydrated;

  bool can(String module, String action) {
    final modKey = ModuleUtils.normalizarModulo(module);
    final actKey = action.trim().toLowerCase();
    // Intentar con clave normalizada y, como fallback, la original
    final set = _perms[modKey] ?? _perms[module];
    if (set == null) return false;
    if (set.contains(actKey)) return true;
    // Fallback: por si hay acciones guardadas con mayúsculas u otras variantes
    return set.contains(action) || set.contains(action.toLowerCase());
  }

  /// Verifica una acción contra múltiples módulos; retorna true si cualquiera coincide.
  bool canAny(List<String> modules, String action) {
    for (final m in modules) {
      if (can(m, action)) return true;
    }
    return false;
  }

  Map<String, Set<String>> get snapshot => _perms;

  Future<void> setForUser(int userId, Map<String, Set<String>> perms) async {
    _userId = userId;
    // Normalizar módulos y acciones a minúsculas para consistencia
    final normalized = <String, Set<String>>{};
    perms.forEach((mod, actions) {
      final key = ModuleUtils.normalizarModulo(mod);
      final normActions = actions.map((e) => e.trim().toLowerCase()).toSet();
      if (normalized.containsKey(key)) {
        normalized[key] = normalized[key]!..addAll(normActions);
      } else {
        normalized[key] = normActions;
      }
    });
    _perms = normalized;
    _hydrated = true;

    await _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_perms.map((k, v) => MapEntry(k, v.toList())));
    await prefs.setString('perms_user_${_userId}_$_prefsVersion', encoded);
  }

  Future<void> loadFromPrefs(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('perms_user_${userId}_$_prefsVersion');
    _userId = userId;
    _isAdmin =
        (prefs.getString('usuario_rol') ?? '').toLowerCase() == 'administrador';
    if (raw == null) {
      _perms = {};
      _hydrated = true;

      return;
    }
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        final normalized = <String, Set<String>>{};
        map.forEach((k, v) {
          final key = ModuleUtils.normalizarModulo(k.toString());
          final set =
              (v as List).map((e) => e.toString().trim().toLowerCase()).toSet();
          normalized[key] = set;
        });
        _perms = normalized;
        _hydrated = true;
      } else {
        _perms = {};
        _hydrated = true;
      }
    } catch (_) {
      _perms = {};
      _hydrated = true;
    }
  }

  /// Intentar hidratar permisos desde preferencias si aún no se ha hecho.
  Future<void> ensureHydratedFromPrefs() async {
    if (_hydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('usuario_id') ?? 0;
      if (userId > 0) {
        _isAdmin =
            (prefs.getString('usuario_rol') ?? '').toLowerCase() ==
            'administrador';
        await loadFromPrefs(userId);
      } else {
        _hydrated = true; // evitar múltiples intentos
      }
    } catch (_) {
      _hydrated = true;
    }
  }
}
