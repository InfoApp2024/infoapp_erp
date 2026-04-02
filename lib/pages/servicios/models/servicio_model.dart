/// ============================================================================
/// ARCHIVO: servicio_model.dart
///
/// PROPÓSITO: Modelo de datos que:
/// - Define la estructura de un servicio
/// - Maneja serialización/deserialización JSON
/// - Implementa métodos de utilidad (copyWith, toString, etc.)
/// - Valida y parsea tipos de datos
/// - Genera formatos para compartir
///
/// USO: Estructura de datos base usada en todo el módulo de servicios
///
/// FUNCIÓN: Define la estructura de datos y lógica de transformación para los servicios.
/// ============================================================================
library;

import 'estado_model.dart'; // ✅ NUEVO IMPORT
import 'package:infoapp/pages/accounting/models/accounting_models.dart'; // ✅ NUEVO IMPORT PARA SOD

class ServicioModel {
  final int? id;
  final int? oServicio;
  final String? fechaIngreso;
  final String? ordenCliente;
  final int? autorizadoPor;
  final String? tipoMantenimiento;
  final String? centroCosto; // NUEVO: Centro de costo
  final int? idEquipo;
  final String? equipoNombre;
  final String? nombreEmp;
  final String? placa;
  final int? estadoId;
  final String? estadoNombre;
  final String? estadoColor;
  final bool? suministraronRepuestos;
  final bool? fotosConfirmadas; // ✅ Flag de confirmación de fotos
  final bool? firmaConfirmada; // ✅ Flag de confirmación de firma
  final bool? personalConfirmado; // ✅ Flag de confirmación de personal
  final String? fechaFinalizacion;
  final bool? anularServicio;
  final String? razon;
  final int? actividadId;
  final String? actividadNombre;
  final int? usuarioCreador; // ✅ NUEVO: Usuario que creó el servicio
  final int?
  usuarioUltimaActualizacion; // ✅ NUEVO: Usuario que realizó la última actualización
  final int? cantidadNotas; // ✅ NUEVO: Cantidad de notas
  final bool? tieneFirma; // ✅ NUEVO: Indica si el servicio ya fue firmado
  final bool?
  bloqueoRepuestos; // ✅ NUEVO: Indica si los repuestos están bloqueados
  final int? clienteId; // ✅ NUEVO: ID del cliente
  final String? clienteNombre; // ✅ NUEVO: Nombre del cliente
  final int? funcionarioId; // ✅ NUEVO: ID del funcionario
  final String? funcionarioNombre; // ✅ NUEVO: Nombre del funcionario
  final double? cantHora; // ✅ NUEVO: Cantidad de horas actividad
  final int? numTecnicos; // ✅ NUEVO: Número de técnicos actividad
  final String? sistemaNombre; // ✅ NUEVO: Nombre del sistema
  final AuditoriaFinancieraModel?
  auditoriaInfo; // ✅ NUEVO: Información de auditoría SoD
  final String?
  estadoComercial; // ✅ NUEVO: Estado comercial (CAUSADO, FACTURADO, etc.)

  const ServicioModel({
    this.id,
    this.oServicio,
    this.fechaIngreso,
    this.ordenCliente,
    this.autorizadoPor,
    this.tipoMantenimiento,
    this.centroCosto, // NUEVO
    this.idEquipo,
    this.equipoNombre,
    this.nombreEmp,
    this.placa,
    this.estadoId,
    this.estadoNombre,
    this.estadoColor,
    this.suministraronRepuestos,
    this.fotosConfirmadas, // ✅ NUEVO
    this.firmaConfirmada, // ✅ NUEVO
    this.personalConfirmado, // ✅ NUEVO
    this.fechaFinalizacion,
    this.anularServicio,
    this.razon,
    this.actividadId,
    this.actividadNombre,
    this.usuarioCreador, // ✅ NUEVO
    this.usuarioUltimaActualizacion, // ✅ NUEVO
    this.cantidadNotas, // ✅ NUEVO
    this.tieneFirma, // ✅ NUEVO
    this.bloqueoRepuestos, // ✅ NUEVO
    this.clienteId, // ✅ NUEVO
    this.clienteNombre, // ✅ NUEVO
    this.funcionarioId, // ✅ NUEVO
    this.funcionarioNombre, // ✅ NUEVO
    this.cantHora, // ✅ NUEVO
    this.numTecnicos, // ✅ NUEVO
    this.sistemaNombre, // ✅ NUEVO
    this.auditoriaInfo, // ✅ NUEVO
    this.estadoComercial, // ✅ NUEVO
  });

  // ✅ Método para crear una copia para duplicar (limpiando campos que no se deben duplicar)
  ServicioModel crearCopiaParaDuplicar() {
    return ServicioModel(
      // ❌ NO duplicar: id, oServicio, fechas, estado
      id: null,
      oServicio: null,
      fechaIngreso: null,
      fechaFinalizacion: null,
      cantidadNotas: null, // ❌ NO duplicar notas
      // ✅ Sí duplicar: datos del servicio
      ordenCliente: ordenCliente,
      autorizadoPor: autorizadoPor,
      tipoMantenimiento: tipoMantenimiento,
      idEquipo: idEquipo,
      equipoNombre: equipoNombre,
      nombreEmp: nombreEmp,
      placa: placa,
      clienteId: clienteId, // ✅ Sí duplicar
      clienteNombre: clienteNombre, // ✅ Sí duplicar
      // ❌ NO duplicar: estado (usar estado inicial)
      estadoId: null,
      estadoNombre: null,
      estadoColor: null,

      // ❌ NO duplicar: repuestos, fotos, firmas y anulación
      suministraronRepuestos: null,
      fotosConfirmadas: null,
      firmaConfirmada: null,
      anularServicio: null,
      razon: null,

      // ❌ NO duplicar: usuarios (se establecerán automáticamente al crear)
      usuarioCreador: null,
      usuarioUltimaActualizacion: null,

      // ❌ NO duplicar: estado de firma/bloqueo
      tieneFirma: null,
      bloqueoRepuestos: null,
    );
  }

  // ✅ Método para generar texto para compartir
  String generarTextoParaCompartir() {
    final buffer = StringBuffer();

    // Encabezado
    buffer.writeln('📋 SERVICIO DE MANTENIMIENTO');
    buffer.writeln('=' * 30);
    buffer.writeln();

    // Información principal
    buffer.writeln('🔹 Número: $numeroServicioFormateado');

    if (ordenCliente != null && ordenCliente!.isNotEmpty) {
      buffer.writeln('📄 Orden Cliente: $ordenCliente');
    }

    if (fechaIngreso != null) {
      buffer.writeln(
        '📅 Fecha Ingreso: ${_formatearFechaParaCompartir(fechaIngreso)}',
      );
    }

    // Información del equipo
    if (equipoNombre != null) {
      buffer.writeln('⚙️ Equipo: $equipoNombre');
    }

    if (placa != null && placa!.isNotEmpty) {
      buffer.writeln('🚗 Placa: $placa');
    }

    if (nombreEmp != null && nombreEmp!.isNotEmpty) {
      buffer.writeln('🏢 Empresa: $nombreEmp');
    }

    // Tipo de mantenimiento
    if (tipoMantenimiento != null) {
      final tipoEmoji = _obtenerEmojiTipoMantenimiento(tipoMantenimiento);
      buffer.writeln('$tipoEmoji Tipo: ${tipoMantenimiento!.toUpperCase()}');
    }

    // Centro de costo
    if (centroCosto != null && centroCosto!.isNotEmpty) {
      buffer.writeln('🏷️ Centro de Costo: $centroCosto');
    }

    // Actividad
    if (actividadNombre != null && actividadNombre!.isNotEmpty) {
      buffer.writeln('🛠️ Actividad: $actividadNombre');
    } else if (actividadId != null) {
      buffer.writeln('🛠️ Actividad ID: $actividadId');
    }

    // Autorizado por (si solo tenemos ID)
    if (autorizadoPor != null) {
      buffer.writeln('👤 Autorizado por (ID): $autorizadoPor');
    }

    // Estado actual
    if (estadoNombre != null) {
      buffer.writeln('📊 Estado: $estadoNombre');
    }

    // Información adicional
    if (tieneRepuestos) {
      buffer.writeln('🔧 Se suministraron repuestos');
    }

    if (estaFinalizado && fechaFinalizacion != null) {
      buffer.writeln(
        '✅ Finalizado: ${_formatearFechaParaCompartir(fechaFinalizacion)}',
      );
    }

    if (estaAnulado) {
      buffer.writeln('❌ SERVICIO ANULADO');
      if (razon != null && razon!.isNotEmpty) {
        buffer.writeln('   Razón: $razon');
      }
    }

    buffer.writeln();
    buffer.writeln('─' * 30);
    buffer.writeln('📱 Generado desde la App de Servicios');
    buffer.writeln(
      '⌚ ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );

    return buffer.toString();
  }

  // ✅ Método para obtener resumen corto para compartir
  String generarResumenCorto() {
    final tipoEmoji = _obtenerEmojiTipoMantenimiento(tipoMantenimiento);
    final estadoText = estaAnulado ? 'ANULADO' : (estadoNombre ?? 'Sin estado');

    return '$tipoEmoji Servicio $numeroServicioFormateado - $estadoText\n'
        '${equipoNombre ?? 'Equipo no especificado'} - ${nombreEmp ?? 'Sin empresa'}\n'
        'Orden: ${ordenCliente ?? 'N/A'} | ${_formatearFechaParaCompartir(fechaIngreso)}';
  }

  // ✅ Método auxiliar para formatear fechas para compartir
  String _formatearFechaParaCompartir(String? fecha) {
    if (fecha == null || fecha.isEmpty) return 'No establecida';
    try {
      final fechaObj = DateTime.parse(fecha);
      return '${fechaObj.day}/${fechaObj.month}/${fechaObj.year}';
    } catch (e) {
      return fecha.length > 10 ? fecha.substring(0, 10) : fecha;
    }
  }

  // ✅ Método auxiliar para obtener emoji del tipo de mantenimiento
  String _obtenerEmojiTipoMantenimiento(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'correctivo':
        return '🔧';
      case 'preventivo':
        return '🛡️';
      case 'predictivo':
        return '📊';
      default:
        return '⚙️';
    }
  }

  // ✅ Crear desde JSON (lo que recibes del backend)
  factory ServicioModel.fromJson(Map<String, dynamic> json) {
    return ServicioModel(
      id: _parseToInt(json['id']),
      oServicio: _parseToInt(json['oServicio'] ?? json['o_servicio']),
      fechaIngreso: (json['fechaIngreso'] ?? json['fecha_ingreso'])?.toString(),
      ordenCliente: (json['ordenCliente'] ?? json['orden_cliente'])?.toString(),
      autorizadoPor: _parseToInt(
        json['autorizadoPor'] ?? json['autorizado_por'],
      ),
      tipoMantenimiento:
          (json['tipoMantenimiento'] ?? json['tipo_mantenimiento'])?.toString(),
      centroCosto: (json['centroCosto'] ?? json['centro_costo'])?.toString(),
      idEquipo: _parseToInt(json['idEquipo'] ?? json['id_equipo']),
      equipoNombre: (json['equipoNombre'] ?? json['equipo_nombre'])?.toString(),
      nombreEmp: (json['nombreEmp'] ?? json['nombre_emp'])?.toString(),
      placa: (json['placa'] ?? json['placa'])?.toString(),
      estadoId: _parseToInt(json['estadoId'] ?? json['estado_id']),
      estadoNombre: (json['estadoNombre'] ?? json['estado_nombre'])?.toString(),
      estadoColor: (json['estadoColor'] ?? json['estado_color'])?.toString(),
      suministraronRepuestos: _parseToBool(
        json['tieneRepuestos'] ?? json['suministraron_repuestos'],
      ),
      fotosConfirmadas: _parseToBool(json['fotos_confirmadas']),
      firmaConfirmada: _parseToBool(json['firma_confirmada']),
      personalConfirmado: _parseToBool(json['personal_confirmado']),
      fechaFinalizacion:
          (json['fechaFinalizacion'] ?? json['fecha_finalizacion'])?.toString(),
      anularServicio: _parseToBool(
        json['estaAnulado'] ?? json['anular_servicio'],
      ),
      razon: json['razon']?.toString(),
      actividadId: _parseToInt(json['actividadId'] ?? json['actividad_id']),
      actividadNombre:
          (json['actividadNombre'] ?? json['actividad_nombre'])?.toString(),
      usuarioCreador: _parseToInt(
        json['usuarioCreador'] ?? json['usuario_creador'],
      ),
      usuarioUltimaActualizacion: _parseToInt(
        json['usuarioUltimaActualizacion'] ??
            json['usuario_ultima_actualizacion'],
      ),
      cantidadNotas: _parseToInt(
        json['cantidadNotas'] ?? json['cantidad_notas'],
      ),
      tieneFirma: _parseToBool(json['tieneFirma'] ?? json['tiene_firma']),
      bloqueoRepuestos: _parseToBool(
        json['bloqueoRepuestos'] ?? json['bloqueo_repuestos'],
      ),
      clienteId: _parseToInt(json['clienteId'] ?? json['cliente_id']),
      clienteNombre:
          (json['clienteNombre'] ?? json['cliente_nombre'])?.toString(),
      funcionarioId: _parseToInt(
        json['funcionarioId'] ?? json['funcionario_id'],
      ),
      funcionarioNombre:
          (json['funcionarioNombre'] ?? json['funcionario_nombre'])?.toString(),
      cantHora:
          (json['cantHora'] ?? json['cant_hora']) != null
              ? double.tryParse(
                (json['cantHora'] ?? json['cant_hora']).toString(),
              )
              : null,
      numTecnicos: _parseToInt(json['numTecnicos'] ?? json['num_tecnicos']),
      sistemaNombre:
          (json['sistemaNombre'] ?? json['sistema_nombre'])?.toString(),
      auditoriaInfo:
          json['auditoria_info'] != null
              ? AuditoriaFinancieraModel.fromJson(json['auditoria_info'])
              : null,
      estadoComercial:
          (json['estadoComercial'] ?? json['estado_comercial'])?.toString(),
    );
  }

  // ✅ Convertir a JSON (para enviar al backend)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (oServicio != null) 'o_servicio': oServicio,
      if (fechaIngreso != null) 'fecha_ingreso': fechaIngreso,
      if (ordenCliente != null) 'orden_cliente': ordenCliente,
      if (autorizadoPor != null) 'autorizado_por': autorizadoPor,
      if (tipoMantenimiento != null) 'tipo_mantenimiento': tipoMantenimiento,
      if (centroCosto != null) 'centro_costo': centroCosto, // NUEVO
      if (idEquipo != null) 'id_equipo': idEquipo,
      if (estadoId != null) 'estado_id': estadoId,
      if (actividadId != null) 'actividad_id': actividadId,
      if (actividadNombre != null) 'actividad_nombre': actividadNombre,
      if (usuarioCreador != null) 'usuario_creador': usuarioCreador, // ✅ NUEVO
      if (usuarioUltimaActualizacion != null)
        'usuario_ultima_actualizacion': usuarioUltimaActualizacion, // ✅ NUEVO
      if (suministraronRepuestos != null)
        'suministraron_repuestos': suministraronRepuestos == true ? 1 : 0,
      if (fotosConfirmadas != null)
        'fotos_confirmadas': fotosConfirmadas == true ? 1 : 0,
      if (firmaConfirmada != null)
        'firma_confirmada': firmaConfirmada == true ? 1 : 0,
      if (personalConfirmado != null)
        'personal_confirmado': personalConfirmado == true ? 1 : 0,
      if (fechaFinalizacion != null) 'fecha_finalizacion': fechaFinalizacion,
      if (anularServicio != null)
        'anular_servicio': anularServicio == true ? 1 : 0,
      if (razon != null) 'razon': razon,
      if (tieneFirma != null) 'tiene_firma': tieneFirma == true ? 1 : 0,
      if (bloqueoRepuestos != null)
        'bloqueo_repuestos': bloqueoRepuestos == true ? 1 : 0,
      if (clienteId != null) 'cliente_id': clienteId, // ✅ NUEVO
      if (funcionarioId != null) 'funcionario_id': funcionarioId, // ✅ NUEVO
      if (cantHora != null) 'cant_hora': cantHora, // ✅ NUEVO
      if (numTecnicos != null) 'num_tecnicos': numTecnicos, // ✅ NUEVO
      if (sistemaNombre != null) 'sistema_nombre': sistemaNombre, // ✅ NUEVO
      if (estadoComercial != null)
        'estado_comercial': estadoComercial, // ✅ NUEVO
    };
  }

  // ✅ Crear copia con modificaciones
  ServicioModel copyWith({
    int? id,
    int? oServicio,
    String? fechaIngreso,
    String? ordenCliente,
    int? autorizadoPor,
    String? tipoMantenimiento,
    String? centroCosto, // NUEVO
    int? idEquipo,
    String? equipoNombre,
    String? nombreEmp,
    String? placa,
    int? estadoId,
    String? estadoNombre,
    String? estadoColor,
    bool? suministraronRepuestos,
    bool? fotosConfirmadas, // ✅ NUEVO
    bool? firmaConfirmada, // ✅ NUEVO
    bool? personalConfirmado, // ✅ NUEVO
    String? fechaFinalizacion,
    bool? anularServicio,
    String? razon,
    int? actividadId,
    String? actividadNombre,
    int? usuarioCreador, // ✅ NUEVO
    int? usuarioUltimaActualizacion, // ✅ NUEVO
    int? cantidadNotas, // ✅ NUEVO
    bool? tieneFirma, // ✅ NUEVO
    bool? bloqueoRepuestos, // ✅ NUEVO
    int? clienteId, // ✅ NUEVO
    String? clienteNombre, // ✅ NUEVO
    int? funcionarioId, // ✅ NUEVO
    String? funcionarioNombre, // ✅ NUEVO
    double? cantHora, // ✅ NUEVO
    int? numTecnicos, // ✅ NUEVO
    String? sistemaNombre, // ✅ NUEVO
    AuditoriaFinancieraModel? auditoriaInfo, // ✅ NUEVO
    String? estadoComercial, // ✅ NUEVO
  }) {
    return ServicioModel(
      id: id ?? this.id,
      oServicio: oServicio ?? this.oServicio,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      ordenCliente: ordenCliente ?? this.ordenCliente,
      autorizadoPor: autorizadoPor ?? this.autorizadoPor,
      tipoMantenimiento: tipoMantenimiento ?? this.tipoMantenimiento,
      centroCosto: centroCosto ?? this.centroCosto, // NUEVO
      idEquipo: idEquipo ?? this.idEquipo,
      equipoNombre: equipoNombre ?? this.equipoNombre,
      nombreEmp: nombreEmp ?? this.nombreEmp,
      placa: placa ?? this.placa,
      estadoId: estadoId ?? this.estadoId,
      estadoNombre: estadoNombre ?? this.estadoNombre,
      estadoColor: estadoColor ?? this.estadoColor,
      suministraronRepuestos:
          suministraronRepuestos ?? this.suministraronRepuestos,
      fotosConfirmadas: fotosConfirmadas ?? this.fotosConfirmadas,
      firmaConfirmada: firmaConfirmada ?? this.firmaConfirmada,
      personalConfirmado: personalConfirmado ?? this.personalConfirmado,
      fechaFinalizacion: fechaFinalizacion ?? this.fechaFinalizacion,
      anularServicio: anularServicio ?? this.anularServicio,
      razon: razon ?? this.razon,
      actividadId: actividadId ?? this.actividadId, // <-- Asegúrate que esté
      actividadNombre: actividadNombre ?? this.actividadNombre,
      usuarioCreador: usuarioCreador ?? this.usuarioCreador, // ✅ NUEVO
      usuarioUltimaActualizacion:
          usuarioUltimaActualizacion ?? this.usuarioUltimaActualizacion,
      cantidadNotas: cantidadNotas ?? this.cantidadNotas,
      tieneFirma: tieneFirma ?? this.tieneFirma, // ✅ NUEVO
      bloqueoRepuestos: bloqueoRepuestos ?? this.bloqueoRepuestos, // ✅ NUEVO
      clienteId: clienteId ?? this.clienteId, // ✅ NUEVO
      clienteNombre: clienteNombre ?? this.clienteNombre, // ✅ NUEVO
      funcionarioId: funcionarioId ?? this.funcionarioId, // ✅ NUEVO
      funcionarioNombre: funcionarioNombre ?? this.funcionarioNombre, // ✅ NUEVO
      cantHora: cantHora ?? this.cantHora, // ✅ NUEVO
      numTecnicos: numTecnicos ?? this.numTecnicos, // ✅ NUEVO
      sistemaNombre: sistemaNombre ?? this.sistemaNombre, // ✅ NUEVO
      auditoriaInfo: auditoriaInfo ?? this.auditoriaInfo, // ✅ NUEVO
      estadoComercial: estadoComercial ?? this.estadoComercial, // ✅ NUEVO
    );
  }

  // ✅ Métodos auxiliares
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

  // ✅ Getters útiles
  bool get estaAnulado => anularServicio == true;
  /// Indica si el servicio ya fue entregado y firmado (o procesado como tal)
  bool get isFirmaConfirmada =>
      (firmaConfirmada ?? false) || (estaFinalizado && tieneFirma == true);

  /// Indica si las fotos de evidencia ya están confirmadas
  bool get isFotosConfirmadas => (fotosConfirmadas ?? false);

  /// Indica si el personal ya ha sido confirmado/asignado
  bool get isPersonalConfirmado => (personalConfirmado ?? false);

  bool get estaFinalizado => fechaFinalizacion != null;
  bool get tieneRepuestos => suministraronRepuestos == true;

  /// ✅ Determina si el servicio es final (trabajo terminado).
  /// Se usa para bloqueos parciales o lógica de "trabajo concluido".
  bool esFinal(List<EstadoModel> estadosConfigurados) {
    if (estaAnulado) return true;

    // 1. Verificar si tenemos el estado configurado en la lista
    if (estadoId != null && estadosConfigurados.isNotEmpty) {
      try {
        final estado = estadosConfigurados.firstWhere((e) => e.id == estadoId);
        // Priorizar la semántica del estado base del enum
        return estado.esEstadoFinal;
      } catch (_) {}
    }

    // 2. Fallback Heurístico (Seguridad o Fallback de carga)
    if (estadoNombre != null) {
      final nombre = estadoNombre!.toUpperCase();
      if ([
        'FINALIZADO',
        'ANULADO',
        'ENTREGADO',
        'CERRADO',
        'TERMINADO',
        'LEGALIZADO',
        'CANCELADO',
      ].any((k) => nombre.contains(k))) {
        return true;
      }
    }

    return false;
  }

  /// ✅ Determina si el servicio es TERMINAL (registro cerrado/inmutable).
  /// LEGALIZADO y CANCELADO son terminales: no permiten más cambios ni transiciones.
  bool esTerminal([List<EstadoModel>? estadosConfigurados]) {
    if (estaAnulado) return true;

    // 1. Si tenemos estados cargados, usar la lógica del enum EstadoBase mapeado
    if (estadoId != null &&
        estadosConfigurados != null &&
        estadosConfigurados.isNotEmpty) {
      try {
        final estado = estadosConfigurados.firstWhere((e) => e.id == estadoId);
        return estado.estadoBase.esTerminal;
      } catch (_) {}
    }

    // 2. Fallback Heurístico (Solo si no hay estados configurados)
    if (estadosConfigurados == null || estadosConfigurados.isEmpty) {
      if (estadoNombre == null) return false;
      final nombre = estadoNombre!.toUpperCase();
      return [
        'LEGALIZADO',
        'CANCELADO',
        'ANULADO',
      ].any((k) => nombre.contains(k));
    }

    return false;
  }

  String get numeroServicioFormateado => '#${oServicio ?? 0}';

  double get tiempoTotal => (cantHora ?? 0.0) * (numTecnicos ?? 0);

  DateTime? get fechaIngresoDate {
    if (fechaIngreso == null) return null;
    try {
      return DateTime.parse(fechaIngreso!);
    } catch (e) {
      return null;
    }
  }

  DateTime? get fechaFinalizacionDate {
    if (fechaFinalizacion == null) return null;
    try {
      return DateTime.parse(fechaFinalizacion!);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'ServicioModel(id: $id, oServicio: $oServicio, ordenCliente: $ordenCliente, estadoNombre: $estadoNombre, usuarioCreador: $usuarioCreador, usuarioUltimaActualizacion: $usuarioUltimaActualizacion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServicioModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
