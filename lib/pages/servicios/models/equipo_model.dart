class EquipoModel {
  final int id;
  final String nombre;
  final String? modelo;
  final String? marca;
  final String? placa;
  final String? codigo;
  final String? nombreEmpresa;
  final bool? activo;
  final int? clienteId; // ✅ NUEVO

  const EquipoModel({
    required this.id,
    required this.nombre,
    this.modelo,
    this.marca,
    this.placa,
    this.codigo,
    this.nombreEmpresa,
    this.activo,
    this.clienteId, // ✅ NUEVO
  });

  factory EquipoModel.fromJson(Map<String, dynamic> json) {
    return EquipoModel(
      id: _parseToInt(json['id']) ?? 0,
      nombre: json['nombre']?.toString() ?? '',
      modelo: json['modelo']?.toString(),
      marca: json['marca']?.toString(),
      placa: json['placa']?.toString(),
      codigo: json['codigo']?.toString(),
      nombreEmpresa: json['nombre_empresa']?.toString(),
      activo: _parseToBool(json['activo']) ?? true,
      clienteId: _parseToInt(json['cliente_id']), // ✅ NUEVO
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      if (modelo != null) 'modelo': modelo,
      if (marca != null) 'marca': marca,
      if (placa != null) 'placa': placa,
      if (nombreEmpresa != null) 'nombre_empresa': nombreEmpresa,
      if (activo != null) 'activo': activo == true ? 1 : 0,
      if (clienteId != null) 'cliente_id': clienteId, // ✅ NUEVO
    };
  }

  String get descripcionCompleta {
    final partes = <String>[nombre];
    if (marca != null && marca!.isNotEmpty) partes.add(marca!);
    if (modelo != null && modelo!.isNotEmpty) partes.add(modelo!);
    return partes.join(' - ');
  }

  String get informacionCompleta {
    final partes = <String>[];
    partes.add(descripcionCompleta);
    if (placa != null && placa!.isNotEmpty) partes.add('($placa)');
    if (nombreEmpresa != null && nombreEmpresa!.isNotEmpty) {
      partes.add('- ${nombreEmpresa!}');
    }
    return partes.join(' ');
  }

  EquipoModel copyWith({
    int? id,
    String? nombre,
    String? modelo,
    String? marca,
    String? placa,
    String? codigo,
    String? nombreEmpresa,
    bool? activo,
    int? clienteId,
  }) {
    return EquipoModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      modelo: modelo ?? this.modelo,
      marca: marca ?? this.marca,
      placa: placa ?? this.placa,
      codigo: codigo ?? this.codigo,
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      activo: activo ?? this.activo,
      clienteId: clienteId ?? this.clienteId, // ✅ NUEVO
    );
  }

  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _parseToBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return null;
  }

  @override
  String toString() {
    return 'EquipoModel(id: $id, nombre: $nombre, placa: $placa, codigo: $codigo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EquipoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
