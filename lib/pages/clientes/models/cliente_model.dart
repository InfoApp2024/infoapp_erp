import 'cliente_perfil_model.dart';
import 'package:infoapp/pages/servicios/models/funcionario_model.dart';

class ClienteModel {
  final int? id;
  final String? tipoPersona;
  final String? documentoNit;
  final String? nombreCompleto;
  final String? email;
  final String? telefonoPrincipal;
  final String? telefonoSecundario;
  final String? direccion;
  final int? ciudadId;
  final String? ciudadNombre; // Para mostrar en lista
  final String? ciudadDepartamento; // Para mostrar en lista
  final int? departamentoId;
  final double? limiteCredito;
  final String? perfil; // Nombre del perfil (antes valor_mo)
  final String? regimenTributario;
  final String? codigoCiiu;
  final bool? esAgenteRetenedor;
  final String? dv;
  final String? emailFacturacion;
  final String? responsabilidadFiscalId;
  final bool? esAutorretenedor;
  final bool? esGranContribuyente;
  final List<ClientePerfilModel> perfiles; // Lista de tarifas
  final List<FuncionarioModel> funcionarios; // Lista de funcionarios
  final bool? activo; // 1 = Activo, 0 = Inactivo
  final String? creadoPor;

  const ClienteModel({
    this.id,
    this.tipoPersona,
    this.documentoNit,
    this.dv,
    this.nombreCompleto,
    this.email,
    this.emailFacturacion,
    this.telefonoPrincipal,
    this.telefonoSecundario,
    this.direccion,
    this.ciudadId,
    this.ciudadNombre,
    this.ciudadDepartamento,
    this.limiteCredito,
    this.perfil,
    this.regimenTributario,
    this.responsabilidadFiscalId,
    this.codigoCiiu,
    this.esAgenteRetenedor,
    this.esAutorretenedor,
    this.esGranContribuyente,
    this.perfiles = const [],
    this.funcionarios = const [],
    this.activo,
    this.creadoPor,
    this.departamentoId,
  });

  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id']?.toString() ?? ''),
      tipoPersona: json['tipo_persona']?.toString(),
      documentoNit: json['documento_nit']?.toString(),
      dv: json['dv']?.toString(),
      nombreCompleto: json['nombre_completo']?.toString(),
      email: json['email']?.toString(),
      emailFacturacion: json['email_facturacion']?.toString(),
      telefonoPrincipal: json['telefono_principal']?.toString(),
      telefonoSecundario: json['telefono_secundario']?.toString(),
      direccion: json['direccion']?.toString(),
      ciudadId:
          json['ciudad_id'] is int
              ? json['ciudad_id']
              : int.tryParse(json['ciudad_id']?.toString() ?? ''),
      ciudadNombre: json['ciudad_nombre']?.toString(),
      ciudadDepartamento: json['departamento']?.toString(),
      departamentoId:
          json['departamento_id'] is int
              ? json['departamento_id']
              : int.tryParse(json['departamento_id']?.toString() ?? ''),
      limiteCredito:
          json['limite_credito'] is num
              ? (json['limite_credito'] as num).toDouble()
              : double.tryParse(json['limite_credito']?.toString() ?? '0.0'),
      perfil: json['perfil']?.toString(), // Ahora es string
      regimenTributario: json['regimen_tributario']?.toString(),
      responsabilidadFiscalId: json['responsabilidad_fiscal_id']?.toString(),
      codigoCiiu: json['codigo_ciiu']?.toString(),
      esAgenteRetenedor:
          json['es_agente_retenedor'] == 1 ||
          json['es_agente_retenedor'] == '1' ||
          json['es_agente_retenedor'] == true,
      esAutorretenedor:
          json['es_autorretenedor'] == 1 ||
          json['es_autorretenedor'] == '1' ||
          json['es_autorretenedor'] == true,
      esGranContribuyente:
          json['es_gran_contribuyente'] == 1 ||
          json['es_gran_contribuyente'] == '1' ||
          json['es_gran_contribuyente'] == true,
      perfiles:
          (json['perfiles'] as List<dynamic>?)
              ?.map((e) => ClientePerfilModel.fromJson(e))
              .toList() ??
          [],
      funcionarios:
          (json['funcionarios'] as List<dynamic>?)
              ?.map((e) => FuncionarioModel.fromJson(e))
              .toList() ??
          [],
      activo: json['estado'] == 1 || json['estado'] == '1',
      creadoPor: json['creado_por']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tipo_persona': tipoPersona,
      'documento_nit': documentoNit,
      'dv': dv,
      'nombre_completo': nombreCompleto,
      'email': email,
      'email_facturacion': emailFacturacion,
      'telefono_principal': telefonoPrincipal,
      'telefono_secundario': telefonoSecundario,
      'direccion': direccion,
      'ciudad_id': ciudadId,
      'limite_credito': limiteCredito,
      'perfil': perfil,
      'regimen_tributario': regimenTributario,
      'responsabilidad_fiscal_id': responsabilidadFiscalId,
      'codigo_ciiu': codigoCiiu,
      'es_agente_retenedor': esAgenteRetenedor == true ? 1 : 0,
      'es_autorretenedor': esAutorretenedor == true ? 1 : 0,
      'es_gran_contribuyente': esGranContribuyente == true ? 1 : 0,
      'perfiles': perfiles.map((e) => e.toJson()).toList(),
      'funcionarios': funcionarios.map((e) => e.toJson()).toList(),
      'estado': activo == true ? 1 : 0,
    };
  }

  ClienteModel copyWith({
    int? id,
    String? tipoPersona,
    String? documentoNit,
    String? dv,
    String? nombreCompleto,
    String? email,
    String? emailFacturacion,
    String? telefonoPrincipal,
    String? telefonoSecundario,
    String? direccion,
    int? ciudadId,
    String? ciudadNombre,
    String? ciudadDepartamento,
    double? limiteCredito,
    String? perfil,
    String? regimenTributario,
    String? responsabilidadFiscalId,
    String? codigoCiiu,
    bool? esAgenteRetenedor,
    bool? esAutorretenedor,
    bool? esGranContribuyente,
    List<ClientePerfilModel>? perfiles,
    List<FuncionarioModel>? funcionarios,
    bool? activo,
  }) {
    return ClienteModel(
      id: id ?? this.id,
      tipoPersona: tipoPersona ?? this.tipoPersona,
      documentoNit: documentoNit ?? this.documentoNit,
      dv: dv ?? this.dv,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      email: email ?? this.email,
      emailFacturacion: emailFacturacion ?? this.emailFacturacion,
      telefonoPrincipal: telefonoPrincipal ?? this.telefonoPrincipal,
      telefonoSecundario: telefonoSecundario ?? this.telefonoSecundario,
      direccion: direccion ?? this.direccion,
      ciudadId: ciudadId ?? this.ciudadId,
      ciudadNombre: ciudadNombre ?? this.ciudadNombre,
      ciudadDepartamento: ciudadDepartamento ?? this.ciudadDepartamento,
      limiteCredito: limiteCredito ?? this.limiteCredito,
      perfil: perfil ?? this.perfil,
      regimenTributario: regimenTributario ?? this.regimenTributario,
      responsabilidadFiscalId:
          responsabilidadFiscalId ?? this.responsabilidadFiscalId,
      codigoCiiu: codigoCiiu ?? this.codigoCiiu,
      esAgenteRetenedor: esAgenteRetenedor ?? this.esAgenteRetenedor,
      esAutorretenedor: esAutorretenedor ?? this.esAutorretenedor,
      esGranContribuyente: esGranContribuyente ?? this.esGranContribuyente,
      perfiles: perfiles ?? this.perfiles,
      funcionarios: funcionarios ?? this.funcionarios,
      activo: activo ?? this.activo,
      creadoPor: creadoPor,
      departamentoId: departamentoId ?? departamentoId,
    );
  }
}
