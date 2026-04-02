class CampoAdicionalModel {
  final int id;
  final String nombreCampo;
  final String tipoCampo;
  final bool obligatorio;
  final String modulo;
  final String? estadoMostrar;
  final dynamic valor; // Puede ser cualquier tipo según el campo

  CampoAdicionalModel({
    required this.id,
    required this.nombreCampo,
    required this.tipoCampo,
    required this.obligatorio,
    required this.modulo,
    this.estadoMostrar,
    this.valor,
  });

  factory CampoAdicionalModel.fromJson(Map<String, dynamic> json) {
    return CampoAdicionalModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      nombreCampo: json['nombre_campo']?.toString() ?? '',
      tipoCampo: json['tipo_campo']?.toString() ?? '',
      obligatorio: json['obligatorio'] == 1,
      // No establecer 'Servicios' como default; dejar vacío si no viene
      modulo: (json['modulo'] ?? '').toString(),
      estadoMostrar: json['estado_mostrar']?.toString(),
      valor: json['valor'],
    );
  }
}
