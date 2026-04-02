class EquipoModel {
  final int? id;
  final String? nombre;
  final String? marca;
  final String? modelo;
  final String? placa;
  final String? codigo;
  final String? nombreEmpresa;
  final String? ciudad;
  final String? planta;
  final String? lineaProd;
  final bool? activo;
  final int? estadoId;
  final String? estadoNombre;
  final String? estadoColor;
  final int? clienteId; // ✅ NUEVO

  const EquipoModel({
    this.id,
    this.nombre,
    this.marca,
    this.modelo,
    this.placa,
    this.codigo,
    this.nombreEmpresa,
    this.ciudad,
    this.planta,
    this.lineaProd,
    this.activo,
    this.estadoId,
    this.estadoNombre,
    this.estadoColor,
    this.clienteId, // ✅ NUEVO
  });

  factory EquipoModel.fromJson(Map<String, dynamic> json) {
    final activo = _parseToBool(json['activo']);
    // No forzar "Activo" si el backend no envía nombre del estado.
    // Usar exclusivamente lo que venga del backend; si no hay nombre, dejar null.
    final estadoNombre = json['estado_nombre']?.toString();
    final estadoColor =
        json['estado_color']?.toString() ?? _colorHexPorEstado(estadoNombre);
    return EquipoModel(
      id: _parseToInt(json['id']),
      nombre: json['nombre']?.toString(),
      marca: json['marca']?.toString(),
      modelo: json['modelo']?.toString(),
      placa: json['placa']?.toString(),
      codigo: json['codigo']?.toString(),
      nombreEmpresa: json['nombre_empresa']?.toString(),
      ciudad: json['ciudad']?.toString(),
      planta: json['planta']?.toString(),
      lineaProd: json['linea_prod']?.toString(),
      activo: activo,
      estadoId: _parseToInt(json['estado_id']),
      estadoNombre: estadoNombre,
      estadoColor: estadoColor,
      clienteId: _parseToInt(json['cliente_id']), // ✅ NUEVO
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (id != null) map['id'] = id;
    if (nombre != null) map['nombre'] = nombre;
    if (marca != null) map['marca'] = marca;
    if (modelo != null) map['modelo'] = modelo;
    if (placa != null) map['placa'] = placa;
    if (codigo != null) map['codigo'] = codigo;
    if (nombreEmpresa != null) map['nombre_empresa'] = nombreEmpresa;
    if (ciudad != null) map['ciudad'] = ciudad;
    if (planta != null) map['planta'] = planta;
    if (lineaProd != null) map['linea_prod'] = lineaProd;
    if (activo != null) map['activo'] = (activo == true ? 1 : 0);
    if (estadoId != null) map['estado_id'] = estadoId;
    if (estadoNombre != null) map['estado_nombre'] = estadoNombre;
    if (estadoColor != null) map['estado_color'] = estadoColor;
    if (clienteId != null) map['cliente_id'] = clienteId; // ✅ NUEVO
    return map;
  }

  Map<String, String> toFormFields() {
    final map = <String, String>{};
    if (id != null) map['id'] = id!.toString();
    if (nombre != null) map['nombre'] = nombre!;
    if (marca != null) map['marca'] = marca!;
    if (modelo != null) map['modelo'] = modelo!;
    if (placa != null) map['placa'] = placa!;
    if (codigo != null) map['codigo'] = codigo!;
    if (nombreEmpresa != null) map['nombre_empresa'] = nombreEmpresa!;
    if (ciudad != null) map['ciudad'] = ciudad!;
    if (planta != null) map['planta'] = planta!;
    if (lineaProd != null) map['linea_prod'] = lineaProd!;
    if (activo != null) map['activo'] = (activo == true ? 1 : 0).toString();
    if (estadoId != null) map['estado_id'] = estadoId!.toString();
    if (estadoNombre != null) map['estado_nombre'] = estadoNombre!;
    if (estadoColor != null) map['estado_color'] = estadoColor!;
    if (clienteId != null) map['cliente_id'] = clienteId!.toString(); // ✅ NUEVO
    return map;
  }

  EquipoModel copyWith({
    int? id,
    String? nombre,
    String? marca,
    String? modelo,
    String? placa,
    String? codigo,
    String? nombreEmpresa,
    String? ciudad,
    String? planta,
    String? lineaProd,
    bool? activo,
    int? estadoId,
    String? estadoNombre,
    String? estadoColor,
  }) {
    return EquipoModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      placa: placa ?? this.placa,
      codigo: codigo ?? this.codigo,
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      ciudad: ciudad ?? this.ciudad,
      planta: planta ?? this.planta,
      lineaProd: lineaProd ?? this.lineaProd,
      activo: activo ?? this.activo,
      estadoId: estadoId ?? this.estadoId,
      estadoNombre: estadoNombre ?? this.estadoNombre,
      estadoColor: estadoColor ?? this.estadoColor,
      clienteId: clienteId ?? clienteId, // ✅ NUEVO
    );
  }

  static int? _parseToInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static bool? _parseToBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().toLowerCase().trim();
    if (s == '1' || s == 'true') return true;
    if (s == '0' || s == 'false') return false;
    return null;
  }

  static String? _mapEstadoDesdeActivo(bool? activo) {
    if (activo == null) return null;
    return activo ? 'Activo' : 'Inactivo';
  }

  static String? _colorHexPorEstado(String? estadoNombre) {
    switch ((estadoNombre ?? '').toLowerCase()) {
      case 'activo':
        return '#4CAF50';
      case 'en mantenimiento':
        return '#FB8C00';
      case 'en préstamo':
        return '#64B5F6';
      case 'inactivo':
        return '#9E9E9E';
      case 'de baja':
        return '#E57373';
      default:
        return null;
    }
  }
}
