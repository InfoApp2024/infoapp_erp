class FinancialPendingItemModel {
  final int id;
  final String numeroOrden;
  final DateTime fechaCreacion;
  final int clienteId;
  final String clienteNombre;
  final double valorSnapshot;
  final double valorRepuestos;
  final double valorManoObra;
  final String estadoComercial;
  final String nombreEstado;
  final int? estadoFinancieroId;
  final DateTime? estadoFinFechaInicio;
  final String? estadoFinancieroNombre;
  final String? estadoFinancieroColor;
  final String? estadoFinancieroCodigo;

  FinancialPendingItemModel({
    required this.id,
    required this.numeroOrden,
    required this.fechaCreacion,
    required this.clienteId,
    required this.clienteNombre,
    required this.valorSnapshot,
    required this.valorRepuestos,
    required this.valorManoObra,
    required this.estadoComercial,
    required this.nombreEstado,
    this.estadoFinancieroId,
    this.estadoFinFechaInicio,
    this.estadoFinancieroNombre,
    this.estadoFinancieroColor,
    this.estadoFinancieroCodigo,
  });

  factory FinancialPendingItemModel.fromJson(Map<String, dynamic> json) {
    return FinancialPendingItemModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      numeroOrden: json['numero_orden'] ?? '',
      fechaCreacion:
          DateTime.tryParse(json['fecha_creacion'] ?? '') ?? DateTime.now(),
      clienteId: int.tryParse(json['cliente_id'].toString()) ?? 0,
      clienteNombre: json['cliente_nombre'] ?? '',
      valorSnapshot: double.tryParse(json['valor_snapshot'].toString()) ?? 0.0,
      valorRepuestos:
          double.tryParse(json['total_repuestos'].toString()) ?? 0.0,
      valorManoObra: double.tryParse(json['total_mano_obra'].toString()) ?? 0.0,
      estadoComercial: json['estado_comercial_cache'] ?? '',
      nombreEstado: json['nombre_estado'] ?? '',
      estadoFinancieroId: json['estado_financiero_id'] != null ? int.tryParse(json['estado_financiero_id'].toString()) : null,
      estadoFinFechaInicio: json['estado_fin_fecha_inicio'] != null ? DateTime.tryParse(json['estado_fin_fecha_inicio'].toString()) : null,
      estadoFinancieroNombre: json['estado_financiero_nombre'],
      estadoFinancieroColor: json['estado_financiero_color'],
      estadoFinancieroCodigo: json['estado_financiero_codigo'],
    );
  }
}

class AccountingEntryDetailModel {
  final int cuentaId;
  final String codigo;
  final String nombre;
  final String tipo; // DEBITO or CREDITO
  final double valor;
  final int? inventoryItemId;

  AccountingEntryDetailModel({
    required this.cuentaId,
    required this.codigo,
    required this.nombre,
    required this.tipo,
    required this.valor,
    this.inventoryItemId,
  });

  factory AccountingEntryDetailModel.fromJson(Map<String, dynamic> json) {
    return AccountingEntryDetailModel(
      cuentaId: int.tryParse(json['cuenta_id'].toString()) ?? 0,
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      tipo: json['tipo'] ?? 'DEBITO',
      valor: double.tryParse(json['valor'].toString()) ?? 0.0,
      inventoryItemId: int.tryParse(json['inventory_item_id'].toString()),
    );
  }
}

class AccountingEntryPreviewModel {
  final String referencia;
  final String evento;
  final List<AccountingEntryDetailModel> detalles;
  final bool periodoAbierto;
  final String fechaActual;
  final double subtotal;
  final double impuesto;
  final double total;
  final double repuestos;
  final double manoObra;
  final bool verDetalleCotizacion;

  AccountingEntryPreviewModel({
    required this.referencia,
    required this.evento,
    required this.detalles,
    required this.periodoAbierto,
    required this.fechaActual,
    required this.subtotal,
    required this.impuesto,
    required this.total,
    required this.repuestos,
    required this.manoObra,
    required this.verDetalleCotizacion,
  });

  factory AccountingEntryPreviewModel.fromJson(Map<String, dynamic> json) {
    final entry = json['asiento'] as Map<String, dynamic>;
    final detallesList =
        (entry['detalles'] as List)
            .map((d) => AccountingEntryDetailModel.fromJson(d))
            .toList();

    final montos = json['montos_base'] as Map<String, dynamic>?;

    return AccountingEntryPreviewModel(
      referencia: entry['referencia'] ?? '',
      evento: entry['evento'] ?? '',
      detalles: detallesList,
      periodoAbierto: json['periodo_abierto'] ?? false,
      verDetalleCotizacion: json['ver_detalle_cotizacion'] ?? true,
      fechaActual: json['fecha_actual'] ?? '',
      subtotal: double.tryParse(montos?['SUBTOTAL']?.toString() ?? '0') ?? 0.0,
      impuesto: double.tryParse(montos?['IMPUESTO']?.toString() ?? '0') ?? 0.0,
      total: double.tryParse(montos?['TOTAL']?.toString() ?? '0') ?? 0.0,
      repuestos:
          double.tryParse(montos?['REPUESTOS_TOTAL']?.toString() ?? '0') ?? 0.0,
      manoObra: double.tryParse(montos?['MANO_OBRA']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class IssuedInvoiceModel {
  final int id;
  final String prefijo;
  final String numeroFactura;
  final String cufe;
  final String qrUrl;
  final String pdfUrl;
  final String metodoPago;
  final DateTime fechaEmision;
  final double totalNeto;
  final double saldoActual;
  final String clienteNombre;
  final String clienteNit;
  final int? estadoFinancieroId;
  final String? estadoFinancieroNombre;
  final String? estadoFinancieroColor;
  final String? estadoFinancieroCodigo;
  final List<String> servicios;

  IssuedInvoiceModel({
    required this.id,
    required this.prefijo,
    required this.numeroFactura,
    required this.cufe,
    required this.qrUrl,
    required this.pdfUrl,
    required this.metodoPago,
    required this.fechaEmision,
    required this.totalNeto,
    required this.saldoActual,
    required this.clienteNombre,
    required this.clienteNit,
    this.estadoFinancieroId,
    this.estadoFinancieroNombre,
    this.estadoFinancieroColor,
    this.estadoFinancieroCodigo,
    this.servicios = const [],
  });

  factory IssuedInvoiceModel.fromJson(Map<String, dynamic> json) {
    return IssuedInvoiceModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      prefijo: json['prefijo'] ?? '',
      numeroFactura: json['numero_factura'] ?? '',
      cufe: json['cufe'] ?? '',
      qrUrl: json['qr_url'] ?? '',
      pdfUrl: json['pdf_url'] ?? '',
      metodoPago: json['metodo_pago'] ?? '',
      fechaEmision:
          DateTime.tryParse(json['fecha_emision'] ?? '') ?? DateTime.now(),
      totalNeto: double.tryParse(json['total_neto'].toString()) ?? 0.0,
      saldoActual: double.tryParse(json['saldo_actual'].toString()) ?? 0.0,
      clienteNombre: json['cliente_nombre'] ?? '',
      clienteNit: json['cliente_nit'] ?? '',
      estadoFinancieroId: json['estado_financiero_id'] != null ? int.tryParse(json['estado_financiero_id'].toString()) : null,
      estadoFinancieroNombre: json['estado_financiero_nombre'],
      estadoFinancieroColor: json['estado_financiero_color'],
      estadoFinancieroCodigo: json['estado_financiero_codigo'],
      servicios: (json['servicios_ids']?.toString() ?? '').split(',').where((s) => s.isNotEmpty).toList(),
    );
  }

  String get fullNumber => '$prefijo-$numeroFactura';
}

class AccountingPeriodModel {
  final int id;
  final int anio;
  final int mes;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String estado;
  final int? usuarioAperturaId;
  final String? usuarioAperturaNombre;
  final DateTime? fechaApertura;
  final int? usuarioCierreId;
  final String? usuarioCierreNombre;
  final DateTime? fechaCierre;

  AccountingPeriodModel({
    required this.id,
    required this.anio,
    required this.mes,
    this.fechaInicio,
    this.fechaFin,
    required this.estado,
    this.usuarioAperturaId,
    this.usuarioAperturaNombre,
    this.fechaApertura,
    this.usuarioCierreId,
    this.usuarioCierreNombre,
    this.fechaCierre,
  });

  factory AccountingPeriodModel.fromJson(Map<String, dynamic> json) {
    return AccountingPeriodModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      anio: int.tryParse(json['anio'].toString()) ?? 0,
      mes: int.tryParse(json['mes'].toString()) ?? 0,
      fechaInicio:
          json['fecha_inicio'] != null
              ? DateTime.tryParse(json['fecha_inicio'])
              : null,
      fechaFin:
          json['fecha_fin'] != null
              ? DateTime.tryParse(json['fecha_fin'])
              : null,
      estado: json['estado'] ?? 'CERRADO',
      usuarioAperturaId: int.tryParse(json['usuario_apertura_id'].toString()),
      usuarioAperturaNombre: json['usuario_apertura_nombre'],
      fechaApertura:
          json['fecha_apertura'] != null
              ? DateTime.tryParse(json['fecha_apertura'])
              : null,
      usuarioCierreId: int.tryParse(json['usuario_cierre_id'].toString()),
      usuarioCierreNombre: json['usuario_cierre_nombre'],
      fechaCierre:
          json['fecha_cierre'] != null
              ? DateTime.tryParse(json['fecha_cierre'])
              : null,
    );
  }

  bool get isOpen => estado == 'ABIERTO';
}

// ============================================================
// Modelo de Auditoría Financiera (SoD)
// ============================================================

class AuditoriaFinancieraModel {
  final bool hayAuditores;
  final bool auditado;
  final bool esAptoParaLegalizado; // true si pasa los 3 checks de pre-vuelo
  final int? auditorId;
  final String? auditorNombre;
  final String? auditorUsuario;
  final DateTime? fechaAuditoria;
  final String? comentario;
  final List<AuditHistoryItem> historial; // ✅ NUEVO: Trazabilidad completa

  const AuditoriaFinancieraModel({
    required this.hayAuditores,
    required this.auditado,
    this.esAptoParaLegalizado = false,
    this.auditorId,
    this.auditorNombre,
    this.auditorUsuario,
    this.fechaAuditoria,
    this.comentario,
    this.historial = const [],
  });

  /// Estado por defecto cuando no se ha consultado aún
  factory AuditoriaFinancieraModel.sinConsultar() =>
      const AuditoriaFinancieraModel(hayAuditores: false, auditado: false);

  factory AuditoriaFinancieraModel.fromJson(Map<String, dynamic> json) {
    final historialRaw = json['historial'] as List?;
    final history =
        historialRaw
            ?.map((item) => AuditHistoryItem.fromJson(item))
            .toList() ??
        [];

    return AuditoriaFinancieraModel(
      hayAuditores: json['hay_auditores'] == true,
      auditado: json['auditado'] == true,
      esAptoParaLegalizado: json['es_apto_para_legalizado'] == true,
      auditorId:
          json['auditor_id'] != null
              ? int.tryParse(json['auditor_id'].toString())
              : null,
      auditorNombre: json['auditor_nombre']?.toString(),
      auditorUsuario: json['auditor_usuario']?.toString(),
      fechaAuditoria: (json['fecha_auditoria'] != null)
          ? (() {
              final fStr = json['fecha_auditoria'].toString();
              if (fStr.isEmpty) return null;
              if (!fStr.contains('Z') && !fStr.contains('+')) {
                return DateTime.tryParse('${fStr}Z')?.toLocal();
              }
              return DateTime.tryParse(fStr)?.toLocal();
            })()
          : null,
      comentario: json['comentario']?.toString(),
      historial: history,
    );
  }

  /// Si hay auditores Y el servicio no fue auditado → debe bloquearse la legalización
  bool get requiereAuditoriaPendiente => hayAuditores && !auditado;
}

/// ✅ NUEVO: Sub-modelo para cada entrada del historial de auditoría
class AuditHistoryItem {
  final int id;
  final DateTime fecha;
  final String comentario;
  final int ciclo;
  final String auditorNombre;

  AuditHistoryItem({
    required this.id,
    required this.fecha,
    required this.comentario,
    required this.ciclo,
    required this.auditorNombre,
  });

  factory AuditHistoryItem.fromJson(Map<String, dynamic> json) {
    // El backend envía 'fecha_auditoria' en el historial.
    final fechaStr = (json['fecha_auditoria'] ?? json['fecha'] ?? '').toString();
    DateTime parsedDate;
    if (fechaStr.isNotEmpty) {
      // Si no tiene zona horaria, asumimos UTC y convertimos a local
      if (!fechaStr.contains('Z') && !fechaStr.contains('+')) {
        parsedDate = DateTime.tryParse('${fechaStr}Z')?.toLocal() ?? DateTime.now();
      } else {
        parsedDate = DateTime.tryParse(fechaStr)?.toLocal() ?? DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return AuditHistoryItem(
      id: json['id'] ?? 0,
      fecha: parsedDate,
      comentario: json['comentario'] ?? '',
      ciclo: json['ciclo'] ?? 1,
      auditorNombre: json['auditor_nombre'] ?? '---',
    );
  }
}
