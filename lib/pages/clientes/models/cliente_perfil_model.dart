class ClientePerfilModel {
  final int? id; // ID de la tabla cliente_perfiles (opcional)
  final int especialidadId;
  final String? nomEspeci; // Para mostrar en UI sin join manual
  final double valor;

  const ClientePerfilModel({
    this.id,
    required this.especialidadId,
    this.nomEspeci,
    required this.valor,
  });

  factory ClientePerfilModel.fromJson(Map<String, dynamic> json) {
    return ClientePerfilModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      especialidadId: json['especialidad_id'] is int 
          ? json['especialidad_id'] 
          : int.tryParse(json['especialidad_id']?.toString() ?? '0') ?? 0,
      nomEspeci: json['nom_especi']?.toString(),
      valor: json['valor'] is double
          ? json['valor']
          : double.tryParse(json['valor']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'especialidad_id': especialidadId,
      'valor': valor,
    };
  }
}
