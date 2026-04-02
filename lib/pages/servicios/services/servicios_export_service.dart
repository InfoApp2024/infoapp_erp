// library; // Removido para evitar conflictos con importaciones

import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/servicio_model.dart';
import '../models/campo_adicional_model.dart';
import 'campos_adicionales_api_service.dart';
import 'servicio_repuestos_api_service.dart';
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import 'servicios_api_service.dart';

class ServiciosExportService {
  static Future<void> exportarServicios({
    required List<ServicioModel> servicios,
    required String formato, // 'csv' | 'excel' | 'pdf'
    List<CampoAdicionalModel> camposAdicionales = const [],
    String? nombreArchivo,
    void Function(String message)? onSuccess,
    void Function(String error)? onError,
  }) async {
    try {
      if (servicios.isEmpty) {
        onError?.call('No hay servicios para exportar');
        return;
      }

      final ids = servicios.map((s) => s.id).whereType<int>().toList();

      // Obtener valores de campos adicionales en batch
      final Map<int, List<CampoAdicionalModel>> camposBatch =
          await CamposAdicionalesApiService.obtenerCamposBatch(
            servicioIds: ids,
            modulo: 'Servicios',
          );

      // Obtener costo de repuestos por servicio
      final Map<int, double> costoRepuestos = {};
      for (final s in servicios) {
        final sid = s.id;
        if (sid == null) continue;

        // 1. Intentar obtener de caché primero (optimización)
        final cachedTotal = ServicioRepuestosApiService.getCachedTotal(sid);
        if (cachedTotal != null) {
          costoRepuestos[sid] = cachedTotal;
          continue;
        }

        // 2. Si no está en caché, intentar fetch siempre con estrategia de doble intento
        // Estrategia idéntica a ServiciosTabla: probar sin detalles primero, luego con detalles.
        // Esto es crucial porque en algunos casos (items eliminados/legacy) la consulta con JOIN (true)
        // puede devolver 0 o fallar, mientras que la simple (false) devuelve el costo correcto.
        double totalCalculado = 0.0;
        bool costoEncontrado = false;

        // Intento 1: Sin detalles (más rápido y robusto para datos históricos/legacy)
        try {
          final resp =
              await ServicioRepuestosApiService.listarRepuestosDeServicio(
                servicioId: sid,
                incluirDetallesItem: false,
                forceRefresh: true,
              );
          if (resp.success && resp.data != null) {
            double t = resp.data!.costoTotal;
            // Fallback local
            if (t == 0.0 && resp.data!.repuestos.isNotEmpty) {
              t = resp.data!.repuestos.fold<double>(
                0.0,
                (sum, r) => sum + r.costoTotal,
              );
            }
            if (t > 0) {
              totalCalculado = t;
              costoEncontrado = true;
            }
          }
        } catch (_) {}

        // Intento 2: Con detalles (si el primero falló o dio 0)
        if (!costoEncontrado) {
          try {
            final resp =
                await ServicioRepuestosApiService.listarRepuestosDeServicio(
                  servicioId: sid,
                  incluirDetallesItem: true,
                  forceRefresh: true,
                );
            if (resp.success && resp.data != null) {
              double t = resp.data!.costoTotal;
              // Fallback local
              if (t == 0.0 && resp.data!.repuestos.isNotEmpty) {
                t = resp.data!.repuestos.fold<double>(
                  0.0,
                  (sum, r) => sum + r.costoTotal,
                );
              }
              totalCalculado = t;
            }
          } catch (_) {}
        }

        costoRepuestos[sid] = totalCalculado;
      }

      // Encabezados base
      final List<String> headers = [
        'Numero Servicio',
        'Fecha Ingreso',
        'Orden Cliente',
        'Tipo Mantenimiento',
        'Centro de Costo',
        'Equipo',
        'Empresa',
        'Placa',
        'Estado',
        'Actividad',
        'Repuestos Suministrados',
        'Total Repuestos',
      ];

      // Agregar nombres de campos adicionales únicos
      final Set<int> adicionalIds = camposAdicionales.map((c) => c.id).toSet();
      final Map<int, String> adicionalNombres = {
        for (final c in camposAdicionales) c.id: c.nombreCampo,
      };
      headers.addAll(
        adicionalIds.map((id) => adicionalNombres[id] ?? 'Campo $id'),
      );

      // Filas
      final List<List<String>> rows = [];
      for (final s in servicios) {
        final sid = s.id ?? -1;
        final double costo = costoRepuestos[sid] ?? 0.0;
        final bool tieneRepuestos =
            (s.suministraronRepuestos == true) || (costo > 0);

        final List<String> base = [
          s.numeroServicioFormateado,
          s.fechaIngreso ?? '',
          s.ordenCliente ?? '',
          s.tipoMantenimiento ?? '',
          s.centroCosto ?? '',
          s.equipoNombre ?? '',
          s.nombreEmp ?? '',
          s.placa ?? '',
          s.estadoNombre ?? '',
          s.actividadNombre ?? (s.actividadId?.toString() ?? ''),
          tieneRepuestos ? 'Si' : 'No',
          tieneRepuestos ? costo.toStringAsFixed(2) : '',
        ];

        final adicionalesServicio = camposBatch[sid] ?? [];
        final Map<int, dynamic> valoresPorId = {
          for (final c in adicionalesServicio) c.id: c.valor,
        };

        for (final id in adicionalIds) {
          final valor = valoresPorId[id];
          base.add(_valorCampoToString(valor));
        }

        rows.add(base);
      }

      // Guardar según formato
      final String defaultName =
          nombreArchivo ?? _nombreArchivoPorFormato(formato);
      switch (formato.toLowerCase()) {
        case 'csv':
          final bytes = _generarCsv(headers, rows);
          await dl.saveBytes(defaultName, bytes, mimeType: 'text/csv');
          onSuccess?.call('CSV generado');
          break;
        case 'excel':
          final bytes = _generarExcel(headers, rows);
          await dl.saveBytes(
            defaultName.endsWith('.xlsx') ? defaultName : '$defaultName.xlsx',
            bytes,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
          onSuccess?.call('Excel generado');
          break;
        case 'pdf':
          final bytes = await _generarPdf(headers, rows);
          await dl.saveBytes(
            defaultName.endsWith('.pdf') ? defaultName : '$defaultName.pdf',
            bytes,
            mimeType: 'application/pdf',
          );
          onSuccess?.call('PDF generado');
          break;
        default:
          onError?.call('Formato no soportado: $formato');
      }
    } catch (e) {
      onError?.call('Error exportando: $e');
    }
  }

  static String _nombreArchivoPorFormato(String formato) {
    final fecha = DateTime.now();
    final base =
        'servicios_${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    switch (formato.toLowerCase()) {
      case 'csv':
        return '$base.csv';
      case 'excel':
        return '$base.xlsx';
      case 'pdf':
        return '$base.pdf';
      default:
        return '$base.dat';
    }
  }

  static List<int> _generarCsv(List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    const bom = [0xEF, 0xBB, 0xBF];
    buffer.writeln(headers.map(_escaparCsv).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escaparCsv).join(','));
    }
    final utf8Bytes = utf8.encode(buffer.toString());
    return [...bom, ...utf8Bytes];
  }

  static List<int> _generarExcel(
    List<String> headers,
    List<List<String>> rows,
  ) {
    final excel = Excel.createExcel();
    final sheet = excel['Servicios'];
    sheet.appendRow(_asTextCells(headers));
    // Estilo de encabezados
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#EEEEEE'),
        fontFamily: 'Arial',
      );
    }
    for (final row in rows) {
      sheet.appendRow(_asTextCells(row));
    }
    final bytes = excel.encode();
    return bytes ?? Uint8List(0);
  }

  static Future<List<int>> _generarPdf(
    List<String> headers,
    List<List<String>> rows,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build:
            (context) => [
              pw.Text(
                'Exportación de Servicios',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
      ),
    );
    return pdf.save();
  }

  /// Exporta servicios dentro de un rango de fechas, aplicando filtros existentes
  static Future<void> exportarServiciosPorFechas({
    required DateTime desde,
    required DateTime hasta,
    required String formato, // 'csv' | 'excel' | 'pdf'
    String? estado,
    String? tipo,
    String? buscar,
    List<CampoAdicionalModel> camposAdicionales = const [],
    String? nombreArchivo,
    void Function(String message)? onSuccess,
    void Function(String error)? onError,
  }) async {
    try {
      // Cargar TODOS los registros usando paginación para no perder datos
      final servicios = <ServicioModel>[];
      int pagina = 1;
      while (true) {
        final r = await ServiciosApiService.listarServicios(
          pagina: pagina,
          limite: 200,
          buscar: buscar,
          estado: estado,
          tipo: tipo,
        );
        final serviciosPagina = (r['servicios'] as List<ServicioModel>);
        servicios.addAll(serviciosPagina);
        final tieneSiguiente = (r['tieneSiguiente'] == true);
        final totalPaginas = (r['totalPaginas'] as int?);
        if (!tieneSiguiente ||
            (totalPaginas != null && pagina >= totalPaginas)) {
          break;
        }
        pagina += 1;
      }

      // Normalizar rango (inicio del día y fin del día)
      final inicio = DateTime(desde.year, desde.month, desde.day);
      final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999);

      final filtrados =
          servicios.where((s) {
            final d = s.fechaIngresoDate;
            if (d == null) return false;
            return !d.isBefore(inicio) && !d.isAfter(fin);
          }).toList();

      if (filtrados.isEmpty) {
        onError?.call('No hay servicios en el rango seleccionado');
        return;
      }

      await exportarServicios(
        servicios: filtrados,
        formato: formato,
        camposAdicionales: camposAdicionales,
        nombreArchivo: nombreArchivo,
        onSuccess: onSuccess,
        onError: onError,
      );
    } catch (e) {
      onError?.call('Error exportando por fechas: $e');
    }
  }

  static String _escaparCsv(String value) {
    final v = value.replaceAll('"', '""');
    if (v.contains(',') || v.contains('\n') || v.contains('\r')) {
      return '"$v"';
    }
    return v;
  }

  static String _valorCampoToString(dynamic valor) {
    if (valor == null) return '';
    if (valor is String) return valor;
    if (valor is num || valor is bool) return valor.toString();
    if (valor is DateTime) {
      return '${valor.year}-${valor.month.toString().padLeft(2, '0')}-${valor.day.toString().padLeft(2, '0')}';
    }
    if (valor is Map) {
      final nombre = valor['nombre']?.toString();
      final ruta = valor['ruta_publica']?.toString();
      if (nombre != null || ruta != null) {
        return nombre ?? ruta ?? jsonEncode(valor);
      }
      return jsonEncode(valor);
    }
    if (valor is List) {
      return valor.map((e) => _valorCampoToString(e)).join(' | ');
    }
    return valor.toString();
  }

  static List<CellValue?> _asTextCells(List<String> values) {
    return values.map<CellValue?>((v) => TextCellValue(v)).toList();
  }
}
