class BirthdayUser {
  final int id;
  final String usuario;
  final String nombreCompleto;
  final String? urlFoto;

  BirthdayUser({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
    this.urlFoto,
  });

  factory BirthdayUser.fromJson(Map<String, dynamic> json) {
    return BirthdayUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      usuario: json['usuario'] ?? '',
      nombreCompleto: json['nombre_completo'] ?? '',
      urlFoto: json['url_foto'],
    );
  }
}
