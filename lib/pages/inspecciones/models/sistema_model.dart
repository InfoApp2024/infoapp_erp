/// ============================================================================
/// ARCHIVO: sistema_model.dart
///
/// PROPÓSITO: Modelo de datos para sistemas de equipos
/// ============================================================================
library;
// library;

class SistemaModel {
  final int? id;
  final String? nombre;
  final String? descripcion;
  final bool? activo;
  final String? createdAt;
  final String? updatedAt;

  const SistemaModel({
    this.id,
    this.nombre,
    this.descripcion,
    this.activo,
    this.createdAt,
    this.updatedAt,
  });

  factory SistemaModel.fromJson(Map<String, dynamic> json) {
    return SistemaModel(
      id: json['id'] as int?,
      nombre: json['nombre']?.toString(),
      descripcion: json['descripcion']?.toString(),
      activo: json['activo'] as bool?,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (activo != null) 'activo': activo,
    };
  }

  SistemaModel copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    bool? activo,
  }) {
    return SistemaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
    );
  }

  @override
  String toString() => 'SistemaModel(id: $id, nombre: $nombre)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SistemaModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
