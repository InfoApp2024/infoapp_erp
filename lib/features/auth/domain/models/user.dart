class User {
  final int id;
  final String usuario;
  final String rol;
  final String estado;
  final String? nombreCompleto;
  final String? correo;
  final String? nit;

  User({
    required this.id,
    required this.usuario,
    required this.rol,
    required this.estado,
    this.nombreCompleto,
    this.correo,
    this.nit,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] is String ? int.tryParse(map['id']) ?? 0 : (map['id'] ?? 0),
      usuario: map['usuario'] ?? '',
      rol: map['rol'] ?? '',
      estado: map['estado'] ?? '',
      nombreCompleto: map['nombre_completo'],
      correo: map['correo'],
      nit: map['nit'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'usuario': usuario,
        'rol': rol,
        'estado': estado,
        'nombre_completo': nombreCompleto,
        'correo': correo,
        'nit': nit,
      };
}
