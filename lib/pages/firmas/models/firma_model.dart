class FirmaModel {
  final int? id;
  final int idServicio;
  final int idStaffEntrega;
  final int idFuncionarioRecibe;
  final String firmaStaffBase64;
  final String firmaFuncionarioBase64;
  final String? notaEntrega;
  final String? notaRecepcion;
  final String? participantesServicio;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Datos expandidos del servicio (cuando viene del backend con JOIN)
  final int? oServicio;
  final String? ordenCliente;
  final String? tipoMantenimiento;
  final String? placa;
  final String? nombreEmpresa;

  // Datos expandidos del staff
  final String? staffNombre;
  final String? staffEmail;

  // Datos expandidos del funcionario
  final String? funcionarioNombre;
  final String? funcionarioCargo;
  final String? funcionarioEmpresa;

  FirmaModel({
    this.id,
    required this.idServicio,
    required this.idStaffEntrega,
    required this.idFuncionarioRecibe,
    required this.firmaStaffBase64,
    required this.firmaFuncionarioBase64,
    this.notaEntrega,
    this.notaRecepcion,
    this.participantesServicio,
    this.createdAt,
    this.updatedAt,
    this.oServicio,
    this.ordenCliente,
    this.tipoMantenimiento,
    this.placa,
    this.nombreEmpresa,
    this.staffNombre,
    this.staffEmail,
    this.funcionarioNombre,
    this.funcionarioCargo,
    this.funcionarioEmpresa,
  });

  // Factory para crear desde JSON (respuesta del backend)
  factory FirmaModel.fromJson(Map<String, dynamic> json) {
    // Conversores robustos
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    String? toString(dynamic v) {
      if (v == null) return null;
      return v.toString();
    }

    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // Lectores con soporte de múltiples claves y tipos
    int readInt(String camel, String snake, {int defaultValue = 0}) {
      return toInt(json[camel] ?? json[snake]) ?? defaultValue;
    }

    int readIntAny(List<String> keys, {int defaultValue = 0}) {
      for (final k in keys) {
        final v = toInt(json[k]);
        if (v != null) return v;
      }
      return defaultValue;
    }

    String readStringAny(List<String> keys, {String defaultValue = ''}) {
      for (final k in keys) {
        final v = toString(json[k]);
        if (v != null && v.isNotEmpty) return v;
      }
      return defaultValue;
    }

    String? readStringOpt(List<String> keys) {
      for (final k in keys) {
        final v = toString(json[k]);
        if (v != null) return v;
      }
      return null;
    }

    DateTime? readDateAny(List<String> keys) {
      for (final k in keys) {
        final v = toDate(json[k]);
        if (v != null) return v;
      }
      return null;
    }

    return FirmaModel(
      id: toInt(json['id']),
      idServicio: readInt('idServicio', 'id_servicio'),
      // Soportar id de entrega por usuario o staff
      idStaffEntrega: readIntAny([
        'idStaffEntrega',
        'id_staff_entrega',
        'idUsuarioEntrega',
        'id_usuario_entrega',
        'usuario_entrega_id',
        'staff_id',
      ]),
      // Soportar id de recepción por usuario o funcionario
      idFuncionarioRecibe: readIntAny([
        'idFuncionarioRecibe',
        'id_funcionario_recibe',
        'idUsuarioRecibe',
        'id_usuario_recibe',
        'usuario_recibe_id',
      ]),
      firmaStaffBase64: readStringAny([
        'firmaStaffBase64',
        'firma_staff_base64',
      ]),
      firmaFuncionarioBase64: readStringAny([
        'firmaFuncionarioBase64',
        'firma_funcionario_base64',
      ]),
      notaEntrega: readStringOpt(['notaEntrega', 'nota_entrega']),
      notaRecepcion: readStringOpt(['notaRecepcion', 'nota_recepcion']),
      participantesServicio:
          readStringOpt(['participantesServicio', 'participantes_servicio']),
      createdAt: readDateAny(['createdAt', 'created_at']),
      updatedAt: readDateAny(['updatedAt', 'updated_at']),
      oServicio: readIntAny(['oServicio', 'o_servicio'], defaultValue: 0),
      ordenCliente: readStringOpt(['ordenCliente', 'orden_cliente']),
      tipoMantenimiento:
          readStringOpt(['tipoMantenimiento', 'tipo_mantenimiento']),
      placa: readStringOpt(['placa', 'placa']),
      nombreEmpresa: readStringOpt(['nombreEmpresa', 'nombre_empresa']),
      // Nombres/Emails del personal (usuarios)
      staffNombre: readStringOpt([
        'staffNombre',
        'staff_nombre',
        'usuarioNombreEntrega',
        'usuario_nombre_entrega',
        'nombre_usuario_entrega',
      ]),
      staffEmail: readStringOpt([
        'staffEmail',
        'staff_email',
        'usuarioEmailEntrega',
        'usuario_email_entrega',
        'email_usuario_entrega',
      ]),
      funcionarioNombre: readStringOpt([
        'funcionarioNombre',
        'funcionario_nombre',
        'usuarioNombreRecibe',
        'usuario_nombre_recibe',
        'nombre_usuario_recibe',
      ]),
      funcionarioCargo: readStringOpt([
        'funcionarioCargo',
        'funcionario_cargo',
        'usuarioCargoRecibe',
        'usuario_cargo_recibe',
      ]),
      funcionarioEmpresa: readStringOpt([
        'funcionarioEmpresa',
        'funcionario_empresa',
        'usuarioEmpresaRecibe',
        'usuario_empresa_recibe',
      ]),
    );
  }

  // Convertir a JSON (para enviar al backend)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_servicio': idServicio,
      'id_staff_entrega': idStaffEntrega,
      'id_funcionario_recibe': idFuncionarioRecibe,
      'firma_staff_base64': firmaStaffBase64,
      'firma_funcionario_base64': firmaFuncionarioBase64,
      'nota_entrega': notaEntrega,
      'nota_recepcion': notaRecepcion,
      'participantes_servicio': participantesServicio,
    };
  }

  // CopyWith para actualizaciones inmutables
  FirmaModel copyWith({
    int? id,
    int? idServicio,
    int? idStaffEntrega,
    int? idFuncionarioRecibe,
    String? firmaStaffBase64,
    String? firmaFuncionarioBase64,
    String? notaEntrega,
    String? notaRecepcion,
    String? participantesServicio,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? oServicio,
    String? ordenCliente,
    String? tipoMantenimiento,
    String? placa,
    String? nombreEmpresa,
    String? staffNombre,
    String? staffEmail,
    String? funcionarioNombre,
    String? funcionarioCargo,
    String? funcionarioEmpresa,
  }) {
    return FirmaModel(
      id: id ?? this.id,
      idServicio: idServicio ?? this.idServicio,
      idStaffEntrega: idStaffEntrega ?? this.idStaffEntrega,
      idFuncionarioRecibe: idFuncionarioRecibe ?? this.idFuncionarioRecibe,
      firmaStaffBase64: firmaStaffBase64 ?? this.firmaStaffBase64,
      firmaFuncionarioBase64:
          firmaFuncionarioBase64 ?? this.firmaFuncionarioBase64,
      notaEntrega: notaEntrega ?? this.notaEntrega,
      notaRecepcion: notaRecepcion ?? this.notaRecepcion,
      participantesServicio:
          participantesServicio ?? this.participantesServicio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      oServicio: oServicio ?? this.oServicio,
      ordenCliente: ordenCliente ?? this.ordenCliente,
      tipoMantenimiento: tipoMantenimiento ?? this.tipoMantenimiento,
      placa: placa ?? this.placa,
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      staffNombre: staffNombre ?? this.staffNombre,
      staffEmail: staffEmail ?? this.staffEmail,
      funcionarioNombre: funcionarioNombre ?? this.funcionarioNombre,
      funcionarioCargo: funcionarioCargo ?? this.funcionarioCargo,
      funcionarioEmpresa: funcionarioEmpresa ?? this.funcionarioEmpresa,
    );
  }

  // Getter para número de servicio formateado
  String get numeroServicioFormateado {
    if (oServicio != null) {
      return '#${oServicio!.toString().padLeft(4, '0')}';
    }
    return '';
  }

  // Validación de firmas
  bool get tieneFirmasCompletas {
    return firmaStaffBase64.isNotEmpty && firmaFuncionarioBase64.isNotEmpty;
  }

  @override
  String toString() {
    return 'FirmaModel(id: $id, idServicio: $idServicio, oServicio: $oServicio, staffNombre: $staffNombre, funcionarioNombre: $funcionarioNombre)';
  }
}
