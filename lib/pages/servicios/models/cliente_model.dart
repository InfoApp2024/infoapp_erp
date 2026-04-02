/// Modelo para representar un Cliente
class ClienteModel {
  final int id;
  final String nombreCompleto;
  final String documentoNit;
  final String? email;
  final String? telefonoPrincipal;
  final String? ciudad;
  final bool activo;

  ClienteModel({
    required this.id,
    required this.nombreCompleto,
    required this.documentoNit,
    this.email,
    this.telefonoPrincipal,
    this.ciudad,
    this.activo = true,
  });

  /// Crear desde JSON
  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombreCompleto:
          (json['nombre_completo'] ?? json['nombre_empresa'] ?? '').toString(),
      documentoNit: (json['documento_nit'] ?? json['codigo'] ?? '').toString(),
      email: json['email']?.toString(),
      telefonoPrincipal: json['telefono_principal']?.toString(),
      ciudad: json['ciudad']?.toString(),
      activo: json['activo'] == 1 || json['activo'] == true,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_completo': nombreCompleto,
      'documento_nit': documentoNit,
      'email': email,
      'telefono_principal': telefonoPrincipal,
      'ciudad': ciudad,
      'activo': activo ? 1 : 0,
    };
  }

  /// Descripción completa para mostrar en dropdowns
  String get descripcion => '$nombreCompleto - $documentoNit';

  @override
  String toString() => descripcion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClienteModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
