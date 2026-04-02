library;

/// Utilidades para manejo de módulos y persistencia de configuración por módulo
class ModuleUtils {
  /// Normaliza el nombre de un módulo a una clave canónica en minúsculas
  static String normalizarModulo(String modulo) {
    final m = modulo.trim().toLowerCase();
    if (m.isEmpty) return 'modulo';

    // Aliases explícitos SIN colapsar submódulos
    switch (m) {
      case 'servicio':
      case 'servicios':
        return 'servicios';
      case 'equipo':
      case 'equipos':
        return 'equipos';
      case 'inventario':
      case 'inventarios':
        return 'inventario';
      case 'proceso_contable':
      case 'procesos_contables':
      case 'procesos':
      case 'proceso':
        return 'procesos_contables';
      case 'geocerca':
      case 'geocercas':
        return 'geocercas';
      default:
        // Mantener submódulos tal cual (p.ej. servicios_autorizado_por, servicios_actividades)
        return m;
    }
  }

  /// Verifica si `moduloCampo` corresponde al `moduloDestino` (normalizado)
  /// Se aceptan variantes como 'servicio'/'servicios' y 'equipo'/'equipos'.
  /// Si `aceptarVacioComoDestino` es true, valores vacíos cuentan como el destino.
  static bool esModulo(
    String? moduloCampo,
    String moduloDestino, {
    bool aceptarVacioComoDestino = false,
  }) {
    final campoRaw = (moduloCampo ?? '').trim().toLowerCase();
    final campoNorm = normalizarModulo(campoRaw);
    final destino = normalizarModulo(moduloDestino);
    // Tratar 'modulo' (sentinela de vacío/genérico) como vacío
    if (campoRaw.isEmpty || campoNorm == 'modulo') {
      return aceptarVacioComoDestino;
    }

    if (destino == 'servicios') {
      return campoRaw == 'servicios' || campoRaw == 'servicio';
    }
    if (destino == 'equipos') {
      return campoRaw == 'equipos' || campoRaw == 'equipo';
    }
    if (destino == 'procesos_contables') {
      return campoRaw == 'procesos_contables' || campoRaw == 'proceso_contable' || campoRaw == 'procesos' || campoRaw == 'proceso';
    }
    return campoNorm == destino;
  }

  /// Construye la clave de preferencias para columnas visibles por módulo
  /// Si [userId] es proporcionado, se crea una clave específica para ese usuario.
  static String prefsKeyColumnasVisibles(String modulo, {int? userId}) {
    final dest = normalizarModulo(modulo);
    if (userId != null) {
      return '${dest}_columnas_visibles_user_$userId';
    }
    return '${dest}_columnas_visibles';
  }
}
