// lib/pages/geocercas/models/personal_activo_model.dart

class PersonalActivo {
  final int registroId;
  final int usuarioId;
  final String nombre;
  final DateTime fechaIngreso;
  final String? fotoIngreso;
  final int minutosDentro;
  final String tiempoDentro;

  PersonalActivo({
    required this.registroId,
    required this.usuarioId,
    required this.nombre,
    required this.fechaIngreso,
    this.fotoIngreso,
    required this.minutosDentro,
    required this.tiempoDentro,
  });

  factory PersonalActivo.fromJson(Map<String, dynamic> json) {
    return PersonalActivo(
      registroId: json['registro_id'] is int 
        ? json['registro_id'] 
        : int.parse(json['registro_id'].toString()),
      usuarioId: json['usuario_id'] is int 
        ? json['usuario_id'] 
        : int.parse(json['usuario_id'].toString()),
      nombre: json['nombre'] ?? 'Usuario Desconocido',
      fechaIngreso: DateTime.parse(json['fecha_ingreso']),
      fotoIngreso: json['foto_ingreso'],
      minutosDentro: json['minutos_dentro'] is int 
        ? json['minutos_dentro'] 
        : int.parse(json['minutos_dentro'].toString()),
      tiempoDentro: json['tiempo_dentro'] ?? '0m',
    );
  }
}
