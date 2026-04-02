/// ============================================================================
/// ARCHIVO: estado_base_enum.dart
/// PROPÓSITO: Enum para estados base del sistema con semántica de negocio
/// ============================================================================
library;

enum EstadoBase {
  abierto('ABIERTO', 'Abierto'),
  programado('PROGRAMADO', 'Programado'),
  asignado('ASIGNADO', 'Asignado'),
  enEjecucion('EN_EJECUCION', 'En Ejecución'),
  finalizado('FINALIZADO', 'Finalizado'),
  cerrado('CERRADO', 'Cerrado'),
  legalizado('LEGALIZADO', 'Legalizado'),
  cancelado('CANCELADO', 'Cancelado');

  /// Cé³digo éºnico del estado (usado en base de datos)
  final String codigo;

  /// Nombre descriptivo del estado
  final String nombre;

  const EstadoBase(this.codigo, this.nombre);

  /// Obtener EstadoBase desde cé³digo de base de datos
  static EstadoBase fromCodigo(String codigo) {
    return EstadoBase.values.firstWhere(
      (e) => e.codigo == codigo.toUpperCase(),
      orElse: () => EstadoBase.abierto, // Default seguro
    );
  }

  /// Indica si es un estado final de trabajo (concluido)
  bool get esFinal =>
      this == EstadoBase.finalizado ||
      this == EstadoBase.cerrado ||
      this == EstadoBase.legalizado ||
      this == EstadoBase.cancelado;

  /// Indica si es un estado TERMINAL (absoluto, inmutable)
  bool get esTerminal =>
      this == EstadoBase.legalizado || this == EstadoBase.cancelado;

  /// Indica si permite edicié³n del servicio por defecto
  bool get permiteEdicion => !esTerminal;

  /// Indica si es un estado activo (pendiente de terminar o legalizar)
  bool get esActivo => !esTerminal;

  /// Obtener todos los códigos como lista
  static List<String> get todosLosCodigos =>
      EstadoBase.values.map((e) => e.codigo).toList();

  @override
  String toString() => nombre;
}
