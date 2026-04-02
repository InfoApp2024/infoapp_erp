/// Enumeración de módulos disponibles en el sistema
/// Cada módulo puede tener su propio flujo de estados y campos adicionales
enum ModuloEnum {
  servicios('Servicios', 'servicio'),
  equipos('Equipos', 'equipo'),
  inspecciones('Inspecciones', 'inspecciones'),
  usuarios('Usuarios', 'usuarios'),
  procesosContables('Procesos contables', 'procesos_contables'),
  staff('Staff', 'staff'),
  inventory('Inventario', 'inventory'),
  financiero('Financiero', 'FINANCIERO');

  const ModuloEnum(this.displayName, this.key);

  final String displayName;
  final String key;

  /// Obtiene el módulo por su clave
  static ModuloEnum? fromKey(String key) {
    for (final modulo in ModuloEnum.values) {
      if (modulo.key == key) return modulo;
    }
    return null;
  }

  /// Obtiene el módulo por su nombre de visualización
  static ModuloEnum? fromDisplayName(String displayName) {
    for (final modulo in ModuloEnum.values) {
      if (modulo.displayName == displayName) return modulo;
    }
    return null;
  }

  /// Lista de todos los módulos disponibles
  static List<ModuloEnum> get all => ModuloEnum.values;

  /// Lista de nombres de visualización
  static List<String> get displayNames => 
      ModuloEnum.values.map((m) => m.displayName).toList();

  /// Lista de claves
  static List<String> get keys => 
      ModuloEnum.values.map((m) => m.key).toList();
}
