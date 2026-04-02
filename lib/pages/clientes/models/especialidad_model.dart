class EspecialidadModel {
  final int? id;
  final String nomEspeci;
  final double valorHr;

  const EspecialidadModel({
    this.id,
    required this.nomEspeci,
    this.valorHr = 0.0,
  });

  factory EspecialidadModel.fromJson(Map<String, dynamic> json) {
    return EspecialidadModel(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id']?.toString() ?? ''),
      nomEspeci: json['nombre'] ?? json['nom_especi'] ?? '',
      valorHr:
          json['valor_hr'] is double
              ? json['valor_hr']
              : double.tryParse(json['valor_hr']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {if (id != null) 'id': id, 'nom_especi': nomEspeci, 'valor_hr': valorHr};
  }
}
