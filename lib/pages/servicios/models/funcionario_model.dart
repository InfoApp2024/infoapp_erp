class FuncionarioModel {
  final int id;
  final String nombre;
  final String? cargo;
  final String? empresa;
  final String? telefono;
  final String? correo;
  final bool activo;
  final int? clienteId;

  const FuncionarioModel({
    required this.id,
    required this.nombre,
    this.cargo,
    this.empresa,
    this.telefono,
    this.correo,
    this.activo = true,
    this.clienteId,
  });

  factory FuncionarioModel.fromJson(Map<String, dynamic> json) {
    return FuncionarioModel(
      id: _parseToInt(json['id']) ?? 0,
      nombre: json['nombre']?.toString() ?? '',
      cargo: json['cargo']?.toString(),
      empresa: json['empresa']?.toString(),
      telefono: json['telefono']?.toString(),
      correo: json['correo']?.toString(),
      activo: _parseToBool(json['activo']) ?? true,
      clienteId: _parseToInt(json['cliente_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      if (cargo != null && cargo!.isNotEmpty) 'cargo': cargo,
      if (empresa != null && empresa!.isNotEmpty) 'empresa': empresa,
      if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
      if (correo != null && correo!.isNotEmpty) 'correo': correo,
      'activo': activo ? 1 : 0,
      if (clienteId != null) 'cliente_id': clienteId,
    };
  }

  FuncionarioModel copyWith({
    int? id,
    String? nombre,
    String? cargo,
    String? empresa,
    String? telefono,
    String? correo,
    bool? activo,
    int? clienteId,
  }) {
    return FuncionarioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      cargo: cargo ?? this.cargo,
      empresa: empresa ?? this.empresa,
      telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo,
      activo: activo ?? this.activo,
      clienteId: clienteId ?? this.clienteId,
    );
  }

  // Getters útiles
  String get nombreCompleto {
    if (cargo != null && cargo!.isNotEmpty) {
      return '$nombre ($cargo)';
    }
    return nombre;
  }

  String get descripcion {
    final partes = <String>[];
    if (cargo != null && cargo!.isNotEmpty) partes.add(cargo!);
    if (empresa != null && empresa!.isNotEmpty) partes.add(empresa!);
    // No solemos poner telefono/correo en la descripción corta, pero se podría si se quisiera
    return partes.isEmpty ? nombre : '$nombre - ${partes.join(' • ')}';
  }

  // Métodos auxiliares mejorados
  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is double) return value.toInt();
    return null;
  }

  static bool? _parseToBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return null;
  }

  @override
  String toString() {
    return 'FuncionarioModel(id: $id, nombre: $nombre, cargo: $cargo, empresa: $empresa, telefono: $telefono, correo: $correo, activo: $activo, clienteId: $clienteId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FuncionarioModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
