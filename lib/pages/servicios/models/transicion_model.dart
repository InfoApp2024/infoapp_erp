class TransicionModel {
  final int id;
  final String nombreEstado;
  final String color;

  TransicionModel({
    required this.id,
    required this.nombreEstado,
    required this.color,
  });

  factory TransicionModel.fromJson(Map<String, dynamic> json) {
    return TransicionModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      nombreEstado: json['nombre_estado']?.toString() ?? '',
      color: json['color']?.toString() ?? '#808080',
    );
  }
}
