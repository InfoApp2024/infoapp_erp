import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:infoapp/features/auth/domain/permission_store.dart';
import '../services/geocerca_service.dart';
import '../controllers/geocercas_controller.dart';
import '../models/registro_geocerca_model.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:infoapp/core/env/server_config.dart';

class GeocercasRegistrosPage extends StatefulWidget {
  const GeocercasRegistrosPage({super.key});

  @override
  State<GeocercasRegistrosPage> createState() => _GeocercasRegistrosPageState();
}

class _GeocercasRegistrosPageState extends State<GeocercasRegistrosPage> {
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarRegistros();
    });
  }

  Future<void> _cargarRegistros() async {
    final ctrl = Provider.of<GeocercasController>(context, listen: false);
    await ctrl.cargarRegistros(inicio: _fechaInicio, fin: _fechaFin);
  }

  Future<void> _descargarExcel() async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Obtener datos
      final data = await GeocercaService.obtenerDatosReporte(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay datos para exportar')),
        );
        return;
      }

      // 2. Crear Excel
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Reporte'];
      excel.delete('Sheet1'); // Borrar hoja por defecto

      // Encabezados
      List<String> headers = [
        'Nombre Usuario',
        'Lugar (Geocerca)',
        'Fecha',
        'Día',
        'Hora Entrada',
        'Hora Salida',
        'Tiempo Total',
        'Observaciones',
      ];

      // Estilo para encabezado (opcional, excel package básico)
      sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

      // Datos
      for (var row in data) {
        // Parsear fecha para obtener el día
        DateTime fecha = DateTime.parse(row['fecha_ingreso']);
        String nombreDia = DateFormat(
          'EEEE',
          'es',
        ).format(fecha); // Requiere inicializar locale

        sheetObject.appendRow([
          TextCellValue(row['usuario'] ?? ''),
          TextCellValue(row['lugar'] ?? ''),
          TextCellValue(row['fecha'] ?? ''),
          TextCellValue(nombreDia),
          TextCellValue(row['hora_ingreso'] ?? ''),
          TextCellValue(row['hora_salida'] ?? 'En sitio'),
          TextCellValue(row['tiempo_total'] ?? ''),
          TextCellValue(row['observaciones'] ?? ''),
        ]);
      }

      final String fileName =
          'Historico_Geocerca_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final fileBytes = excel.encode();

      if (fileBytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      // --- LÓGICA PARA WEB ---
      if (kIsWeb) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        // Se agrega al body, se hace clic y se elimina para evitar doble descarga
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute('download', fileName)
              ..style.display = 'none';
        html.document.body!.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Descargando: $fileName')));
        }
        return;
      }

      // --- LÓGICA PARA MÓVIL (Android/iOS) ---
      final directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // 4. Compartir / Abrir
      if (!mounted) return;

      // Usar Share Plus para mejor experiencia (permite guardar en Drive, enviar por WhatsApp, etc.)
      try {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Reporte de Registros Geocercas',
          subject: 'Reporte $fileName',
        );
      } catch (_) {
        // Fallback a OpenFilex si compartir falla
        await OpenFilex.open(filePath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reporte generado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Cerrar loading si falló
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
      _cargarRegistros();
    }
  }

  void _showRemotePhoto(String url, String title) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(title),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  backgroundColor: BrandingService().primaryColor,
                  foregroundColor: Colors.white,
                ),
                Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (context, error, stackTrace) => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No se pudo cargar la imagen del servidor'),
                      ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = BrandingService();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final bool canList = PermissionStore.instance.can('geocercas', 'listar');

    String getFullImageUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return '';
      final apiRoot = ServerConfig.instance.apiRoot();
      // apiRoot es algo como https://.../API_Infoapp
      // relativePath es uploads/geocercas/xxx.jpg
      // El backend suele estar un nivel arriba de API_Infoapp o en la misma raíz.
      // Basado en baseUrlFor, el backend real es la carpeta superior a API_Infoapp
      final backendRoot = apiRoot.replaceFirst('/API_Infoapp', '');
      return '$backendRoot/backend/$relativePath';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros de Ingreso/Salida'),
        backgroundColor: branding.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar a Excel',
            onPressed: canList ? _descargarExcel : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: canList ? _cargarRegistros : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _fechaInicio == null
                          ? 'Desde'
                          : DateFormat('dd/MM/yyyy').format(_fechaInicio!),
                    ),
                    onPressed: () => _seleccionarFecha(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _fechaFin == null
                          ? 'Hasta'
                          : DateFormat('dd/MM/yyyy').format(_fechaFin!),
                    ),
                    onPressed: () => _seleccionarFecha(false),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _fechaInicio = null;
                      _fechaFin = null;
                    });
                    _cargarRegistros();
                  },
                ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child:
                !canList
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No tienes permiso para listar registros',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : Consumer<GeocercasController>(
                      builder: (context, ctrl, child) {
                        if (ctrl.loading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (ctrl.registros.isEmpty) {
                          return const Center(
                            child: Text('No hay registros encontrados'),
                          );
                        }

                        return ListView.builder(
                          itemCount: ctrl.registros.length,
                          itemBuilder: (context, index) {
                            final registro = ctrl.registros[index];
                            return _buildRegistroCard(
                              registro,
                              dateFormat,
                              getFullImageUrl,
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistroCard(
    RegistroGeocerca item,
    DateFormat fmt,
    String Function(String?) getUrl,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: const Icon(Icons.location_on, color: Colors.blue),
        ),
        title: Text(item.nombreUsuario ?? 'Usuario Desconocido'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lugar: ${item.nombreGeocerca}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.login, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(fmt.format(item.fechaIngreso)),
                const Spacer(),
                if (item.fotoIngreso != null)
                  GestureDetector(
                    onTap:
                        () => _showRemotePhoto(
                          getUrl(item.fotoIngreso),
                          'Evidencia Entrada',
                        ),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(
                          image: NetworkImage(getUrl(item.fotoIngreso)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (item.fechaSalida != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.logout, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(fmt.format(item.fechaSalida!)),
                      const Spacer(),
                      if (item.fotoSalida != null)
                        GestureDetector(
                          onTap:
                              () => _showRemotePhoto(
                                getUrl(item.fotoSalida),
                                'Evidencia Salida',
                              ),
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: DecorationImage(
                                image: NetworkImage(getUrl(item.fotoSalida)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      Text(
                        'Duración: ${item.duracion ?? ""}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  if (item.observaciones != null &&
                      item.observaciones!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.observaciones!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Actualmente en el sitio',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
