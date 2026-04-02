class NotaModel {
  final int id;
  final int idServicio;
  final String nota;
  final String fecha;
  final String hora;
  final String usuario;
  final int usuarioId;
  final bool esAutomatica;

  NotaModel({
    required this.id,
    required this.idServicio,
    required this.nota,
    required this.fecha,
    required this.hora,
    required this.usuario,
    required this.usuarioId,
    this.esAutomatica = false,
  });

  factory NotaModel.fromJson(Map<String, dynamic> json) {
    return NotaModel(
      id: json['id'],
      idServicio: json['id_servicio'],
      nota: json['nota'],
      fecha: json['fecha'],
      hora: json['hora'],
      usuario: json['usuario'],
      usuarioId: json['usuario_id'],
      esAutomatica: json['es_automatica'] == 1 || json['es_automatica'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_servicio': idServicio,
      'nota': nota,
      'fecha': fecha,
      'hora': hora,
      'usuario': usuario,
      'usuario_id': usuarioId,
      'es_automatica': esAutomatica ? 1 : 0,
    };
  }
}
