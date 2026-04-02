import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/env/server_config.dart';
import '../../../features/auth/data/auth_service.dart';
import '../models/accounting_models.dart';

class FinancialManagementService {
  static final FinancialManagementService instance =
      FinancialManagementService._();
  FinancialManagementService._();

  String get baseUrl => ServerConfig.instance.baseUrlFor('accounting');

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  /// Lista servicios pendientes por facturar
  Future<List<FinancialPendingItemModel>> getPendingServices() async {
    final url = '$baseUrl/listar_servicios_pendientes.php';
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success']) {
        final List data = jsonResponse['data'];
        return data
            .map((item) => FinancialPendingItemModel.fromJson(item))
            .toList();
      }
    }
    throw Exception('Error al cargar servicios pendientes');
  }

  /// Previsualiza el asiento contable
  Future<AccountingEntryPreviewModel> previewEntry(int servicioId) async {
    final url = '$baseUrl/previsualizar_asiento.php?servicio_id=$servicioId';
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success']) {
        return AccountingEntryPreviewModel.fromJson(jsonResponse['data']);
      } else {
        throw Exception(
          jsonResponse['message'] ?? 'Error al previsualizar asiento',
        );
      }
    }
    throw Exception('Error de conexión con el servidor');
  }

  /// Confirma la causación interna
  Future<bool> confirmAccrual(int servicioId) async {
    final url = '$baseUrl/confirmar_causacion.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({'servicio_id': servicioId}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse['success'];
    }
    return false;
  }

  /// Lista facturas emitidas (Phase 3.2)
  Future<List<IssuedInvoiceModel>> getIssuedInvoices() async {
    final url = '$baseUrl/listar_facturas_emitidas.php';
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success']) {
        final List data = jsonResponse['data'];
        return data.map((item) => IssuedInvoiceModel.fromJson(item)).toList();
      }
    }
    throw Exception('Error al cargar facturas emitidas');
  }

  /// Genera Factura Comercial (Phase 3 Atomic & 3.8)
  Future<Map<String, dynamic>> createInvoice({
    required int clienteId,
    required List<int> serviciosIds,
    String metodoPago = 'CONTADO',
    String prefijo = 'FEV',
    String observaciones = '',
  }) async {
    final url = '$baseUrl/create_invoice.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({
        'cliente_id': clienteId,
        'servicios_ids': serviciosIds,
        'metodo_pago': metodoPago,
        'prefijo': prefijo,
        'observaciones': observaciones,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Error al generar factura comercial');
  }

  /// Devuelve un servicio a operaciones (Phase 3.8)
  Future<bool> devolverAOperaciones(int servicioId, String motivo) async {
    final url = '$baseUrl/devolver_a_operaciones.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({'servicio_id': servicioId, 'motivo': motivo}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse['success'] ?? false;
    } else {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(jsonResponse['message'] ?? 'Error al devolver servicio');
    }
  }

  /// Descarga el PDF de la Cotización Pro-forma (#3.13)
  Future<void> downloadCotizacion(int servicioId) async {
    final token = await AuthService.getBearerToken();
    // Limpiamos la base URL para asegurar que apuntamos a la raíz del backend
    final baseUrlClean = baseUrl.replaceAll('/accounting', '');
    final url =
        '$baseUrlClean/accounting/generar_cotizacion_pdf.php?servicio_id=$servicioId&token=$token';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('No se pudo abrir el enlace de la cotización');
    }
  }

  /// Verifica si la configuración de Factus está completa (#3.18)
  Future<bool> checkFacturationConfig() async {
    try {
      final url = '$baseUrl/verificar_config_facturacion.php';
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        return jsonResponse['enabled'] ?? false;
      }
    } catch (e) {
      print('Error al verificar config de facturación: $e');
    }
    return false;
  }

  /// Obtiene la configuración actual de Factus (#3.18)
  Future<Map<String, dynamic>> getFactusSettings() async {
    final url = '$baseUrl/get_factus_settings.php';
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success']) {
        return jsonResponse['data'];
      }
    }
    throw Exception('Error al obtener la configuración de Factus');
  }

  /// Guarda la configuración de Factus (#3.18)
  Future<bool> saveFactusSettings(Map<String, String> settings) async {
    final url = '$baseUrl/save_factus_settings.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode(settings),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse['success'] ?? false;
    }
    return false;
  }

  /// Actualiza un valor del snapshot (MO o Repuestos) con auditoría obligatoria (#3.19)
  Future<bool> updateSnapshotValue({
    required int servicioId,
    required String campo, // 'MANO_OBRA' or 'REPUESTOS'
    required double nuevoValor,
    required String motivo,
  }) async {
    final url = '$baseUrl/update_snapshot_values.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({
        'servicio_id': servicioId,
        'campo': campo,
        'nuevo_valor': nuevoValor,
        'motivo': motivo,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse['success'] ?? false;
    } else {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(jsonResponse['message'] ?? 'Error al actualizar valor');
    }
  }

  /// Obtiene el historial de ajustes financieros (#3.19)
  Future<List<Map<String, dynamic>>> getSnapshotHistory(int servicioId) async {
    final url = '$baseUrl/get_snapshot_history.php?servicio_id=$servicioId';
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success']) {
        return List<Map<String, dynamic>>.from(jsonResponse['data']);
      }
    }
    return [];
  }

  /// Actualiza la preferencia de visibilidad del detalle en la cotización (#3.20)
  Future<bool> updateQuoteVisibility(int servicioId, bool verDetalle) async {
    final url = '$baseUrl/update_quote_visibility.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({
        'servicio_id': servicioId,
        'ver_detalle': verDetalle ? 1 : 0,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse['success'] ?? false;
    }
    return false;
  }

  /// Actualiza el valor TOTAL de un repuesto individual (#3.21)
  /// El backend calcula el nuevo costo unitario dividiendo el total por la cantidad.
  Future<bool> updateSparePartValue({
    required int servicioId,
    required int inventoryItemId,
    required double nuevoValorTotal, // Valor total del ítem (no unitario)
    required String motivo,
  }) async {
    final url = '$baseUrl/update_spare_part_value.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({
        'servicio_id': servicioId,
        'inventory_item_id': inventoryItemId,
        'nuevo_valor_total': nuevoValorTotal, // ← enviar total, no unitario
        'motivo': motivo,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse['success'] ?? false;
    } else {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(
        jsonResponse['message'] ?? 'Error al actualizar valor del repuesto',
      );
    }
  }

  // ============================================================
  // Módulo de Auditoría Financiera (SoD)
  // ============================================================

  /// Consulta el estado de auditoría de un servicio.
  /// Devuelve [AuditoriaFinancieraModel] con: si hay auditores,
  /// si está auditado, y datos del auditor si aplica.
  Future<AuditoriaFinancieraModel> checkAuditoria(int servicioId) async {
    final url = '$baseUrl/check_auditoria.php?servicio_id=$servicioId';
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return AuditoriaFinancieraModel.fromJson(jsonResponse);
      }
      throw Exception(
        jsonResponse['message'] ?? 'Error al verificar auditoría',
      );
    }
    throw Exception('Error de conexión al verificar auditoría');
  }

  /// Registra la auditoría financiera de un servicio.
  /// Solo puede ser llamado por usuarios con [esAuditor = true].
  /// Retorna el [AuditoriaFinancieraModel] actualizado con los datos del registro.
  Future<AuditoriaFinancieraModel> registrarAuditoria(
    int servicioId, {
    String? comentario,
    bool esExcepcion = false,
  }) async {
    final url = '$baseUrl/registrar_auditoria.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({
        'servicio_id': servicioId,
        'es_excepcion': esExcepcion ? 1 : 0,
        if (comentario != null && comentario.isNotEmpty)
          'comentario': comentario,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return AuditoriaFinancieraModel.fromJson({
          'hay_auditores': true,
          'auditado': true,
          'auditor_id': jsonResponse['auditor_id'],
          'auditor_nombre': jsonResponse['auditor_nombre'],
          'auditor_usuario': null,
          'fecha_auditoria': jsonResponse['fecha_auditoria'],
          'comentario': jsonResponse['comentario'],
        });
      }
      throw Exception(
        jsonResponse['message'] ?? 'Error al registrar auditoría',
      );
    }
    final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(jsonResponse['message'] ?? 'Error al registrar auditoría');
  }

  /// Realiza el análisis de la cotización usando IA Gemini (#3.22)
  Future<Map<String, dynamic>> analizarCotizacionIA(int servicioId, {bool refresh = false}) async {
    final baseUrlIA = baseUrl.replaceAll('/accounting', '/chatbot');
    final url = '$baseUrlIA/analizar_cotizacion.php?servicio_id=$servicioId${refresh ? '&refresh=1' : ''}';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success']) {
        return jsonResponse;
      }
      throw Exception(jsonResponse['error'] ?? 'Error en el análisis de IA');
    }
    throw Exception('Error de conexión al consultar la IA');
  }

  /// Cambia el estado financiero manualmente (Phase 4)
  Future<bool> changeFinancialState({
    int? servicioId,
    int? facturaId,
    required int nuevoEstadoId,
  }) async {
    final url = '$baseUrl/cambiar_estado_financiero.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({
        if (servicioId != null) 'servicio_id': servicioId,
        if (facturaId != null) 'factura_id': facturaId,
        'nuevo_estado_id': nuevoEstadoId,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse['success'] ?? false;
    } else {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(jsonResponse['message'] ?? 'Error al cambiar estado financiero');
    }
  }

  /// Obtiene los estados financieros configurados
  Future<List<Map<String, dynamic>>> getFinancialStates() async {
    final workflowUrl = baseUrl.replaceAll('/accounting', '/workflow');
    final response = await http.get(
      Uri.parse('$workflowUrl/listar_estados.php?modulo=FINANCIERO'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse is Map && jsonResponse['data'] is List) {
        return List<Map<String, dynamic>>.from(jsonResponse['data']);
      } else if (jsonResponse is Map && jsonResponse['estados'] is List) {
        return List<Map<String, dynamic>>.from(jsonResponse['estados']);
      } else if (jsonResponse is List) {
        return List<Map<String, dynamic>>.from(jsonResponse);
      }
    }
    return [];
  }

  /// Obtiene los estados financieros PERMITIDOS (transiciones) desde el estado actual
  Future<List<Map<String, dynamic>>> getAvailableTransitions({
    int? servicioId,
    int? facturaId,
  }) async {
    final url = '$baseUrl/obtener_transiciones_financieras.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({
        if (servicioId != null) 'servicio_id': servicioId,
        if (facturaId != null) 'factura_id': facturaId,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true && jsonResponse['data'] is List) {
        return List<Map<String, dynamic>>.from(jsonResponse['data']);
      }
    }
    
    // Si falla, retornamos la lista completa como fallback para no bloquear al usuario
    return getFinancialStates();
  }
}
