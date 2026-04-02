import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../../servicios/services/download_service.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../../plantillas/providers/plantilla_provider.dart';
import '../../firmas/services/firmas_service.dart';
import '../../firmas/models/firma_model.dart';
import 'package:infoapp/pages/plantillas/utils/html_preview_utils.dart';
import 'package:infoapp/core/env/server_config.dart';

class PreviewInformeDialog extends StatefulWidget {
  final int servicioId;
  const PreviewInformeDialog({super.key, required this.servicioId});

  @override
  State<PreviewInformeDialog> createState() => _PreviewInformeDialogState();
}

class _PreviewInformeDialogState extends State<PreviewInformeDialog> {
  WebViewController? _webViewController;
  bool _isWebViewReady = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  // ========================================
  // INICIALIZAR WEBVIEW
  // ========================================
  void _initWebView() {
    _webViewController = WebViewController();

    // En web, setJavaScriptMode no está implementado. Evitar llamarlo.
    if (!kIsWeb) {
      try {
        _webViewController!.setJavaScriptMode(JavaScriptMode.unrestricted);
      } catch (e) {
        debugPrint('⚠️ setJavaScriptMode no soportado: $e');
      }
    }

    try {
      // Evitar llamar setBackgroundColor en web (no implementado)
      if (!kIsWeb) {
        _webViewController!.setBackgroundColor(Colors.white);
      }
      _webViewController!.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isWebViewReady = true);
            //               print('🔵 WebView cargado exitosamente');
          },
          onWebResourceError: (WebResourceError error) {
            //               print('❌ Error en WebView: ${error.description}');
          },
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Configuración parcial de WebView en web: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final plantillaProvider = context.read<PlantillaProvider>();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 640,
          height: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.picture_as_pdf, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Vista previa del informe',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: FutureBuilder<Map<String, dynamic>?>(
                      future: plantillaProvider.getPreview(widget.servicioId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return _buildPreviewError(
                            'Error al generar vista previa: ${snapshot.error}',
                          );
                        }
                        final data = snapshot.data;
                        if (data == null) {
                          return _buildPreviewError(
                            'No se pudo generar la vista previa. Intenta más tarde.',
                          );
                        }
                        // Intentar múltiples formatos de respuesta
                        final pdfUrl =
                            (data['pdf_url'] ??
                                    data['url_pdf'] ??
                                    data['url'] ??
                                    data['preview_url'])
                                ?.toString();
                        final rutaPublica =
                            (data['ruta_publica'] ??
                                    data['url_completa'] ??
                                    data['ruta'])
                                ?.toString();
                        final archivo = data['archivo'];
                        final html =
                            (data['html_procesado'] ??
                                    data['html'] ??
                                    data['contenido_html'] ??
                                    data['rendered_html'])
                                ?.toString();

                        // Caso: URL directa
                        if (pdfUrl != null && pdfUrl.isNotEmpty) {
                          return _buildPreviewPdf(context, pdfUrl);
                        }
                        // Caso: Ruta pública del archivo
                        if (rutaPublica != null && rutaPublica.isNotEmpty) {
                          final urlCompleta = _construirUrlCompleta(
                            rutaPublica,
                          );
                          return _buildPreviewPdf(context, urlCompleta);
                        }
                        // Caso: Objeto archivo con ruta
                        if (archivo is Map<String, dynamic>) {
                          final ruta =
                              (archivo['ruta_publica'] ??
                                      archivo['url_completa'] ??
                                      archivo['ruta'])
                                  ?.toString();
                          if (ruta != null && ruta.isNotEmpty) {
                            final urlCompleta = _construirUrlCompleta(ruta);
                            return _buildPreviewPdf(context, urlCompleta);
                          }
                        }
                        // Caso: HTML
                        if (html != null && html.isNotEmpty) {
                          return _buildPreviewHtml(context, html);
                        }
                        return _buildPreviewError(
                          'Respuesta desconocida del servidor\n${data.toString()}',
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewPdf(BuildContext context, String pdfUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.link, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pdfUrl,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  DownloadService.abrirArchivoEnNuevaPestana(pdfUrl);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await DownloadService.descargarArchivo(
                    nombreArchivo: 'informe_preview.pdf',
                    rutaPublica: pdfUrl,
                    onSuccess:
                        (m) => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(m),
                            duration: const Duration(seconds: 2),
                          ),
                        ),
                    onError:
                        (e) => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e),
                            duration: const Duration(seconds: 3),
                          ),
                        ),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Descargar'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: pdfUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL copiada al portapapeles'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar URL'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'El informe se abrirá en una nueva pestaña o aplicación PDF.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Future<String> _processHtmlWithFirmas(String html) async {
    try {
      final result = await FirmasService.obtenerFirmasPorServicio(widget.servicioId);
      FirmaModel? firma;
      if (result['success'] == true) {
        final list = result['firmas'] as List<FirmaModel>;
        if (list.isNotEmpty) firma = list.first;
      }
      return await HtmlPreviewUtils.prepareHtmlCompleto(html, firma);
    } catch (e) {
      debugPrint('⚠️ Error en _processHtmlWithFirmas: $e');
      return await HtmlPreviewUtils.prepareHtmlCompleto(html, null);
    }
  }

  Widget _buildPreviewHtml(BuildContext context, String html) {
    return FutureBuilder<String>(
      future: _processHtmlWithFirmas(html),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final htmlCompleto = snapshot.data ?? '';

        if (_webViewController != null && htmlCompleto.isNotEmpty) {
          _webViewController!.loadHtmlString(htmlCompleto);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Vista previa renderizada. Haz clic para descargar el PDF',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _descargarPdfDesdeHtml(context, htmlCompleto);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al generar PDF: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Descargar PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 450,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _webViewController != null
                    ? WebViewWidget(controller: _webViewController!)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        );
      },
    );
  }

  // ========================================
  // MÉTODO PARA DESCARGAR PDF
  // ========================================
  /// Genera y descarga un PDF usando el mismo HTML mostrado en la vista previa.
  /// Intenta el endpoint de vista previa (`vista_previa_pdf.php`) pasando el HTML
  /// procesado para que el backend genere un PDF idéntico a la visualización.
  Future<void> _descargarPdfDesdeHtml(
    BuildContext context,
    String htmlProcesado,
  ) async {
    try {
      final token = await AuthService.getBearerToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final response = await http.post(
        Uri.parse(
          '${ServerConfig.instance.apiRoot()}/informes/vista_previa_pdf.php',
        ),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode({
          // Enviar HTML directamente para que el backend renderice
          'contenido_html': htmlProcesado,
          // Adjuntar el servicio_id para resolución de rutas/recursos en backend
          'servicio_id': widget.servicioId,
          // Solicitar explícitamente la generación del PDF en este flujo
          'generar_pdf': true,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.statusCode}');
      }

      // Soporte: respuesta binaria PDF directa
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.contains('application/pdf') ||
          (response.bodyBytes.length >= 4 &&
              String.fromCharCodes(response.bodyBytes.sublist(0, 4)) ==
                  '%PDF')) {
        try {
          await dl.saveBytes(
            'informe_preview.pdf',
            response.bodyBytes,
            mimeType: 'application/pdf',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archivo descargado: informe_preview.pdf'),
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error descargando archivo: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(
          data['message'] ?? 'No se pudo generar el PDF desde HTML',
        );
      }

      final inner = (data['data'] as Map<String, dynamic>?);
      final pdfUrl =
          inner == null
              ? null
              : (inner['pdf_url'] ??
                      inner['url_pdf'] ??
                      inner['preview_url'] ??
                      inner['ruta_publica'])
                  ?.toString();

      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        // Abrir/descargar usando servicio de descargas
        await DownloadService.descargarArchivo(
          nombreArchivo: 'informe_preview.pdf',
          rutaPublica: pdfUrl,
          onSuccess:
              (m) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(m),
                  duration: const Duration(seconds: 2),
                ),
              ),
          onError:
              (e) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e),
                  duration: const Duration(seconds: 3),
                ),
              ),
        );
        return;
      }

      // Si no vino URL, intentar si el backend devolvió bytes/base64
      final base64 = inner?['pdf_base64']?.toString();
      if (base64 != null && base64.isNotEmpty) {
        final bytes = base64Decode(base64);
        try {
          await dl.saveBytes(
            'informe_preview.pdf',
            bytes,
            mimeType: 'application/pdf',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archivo descargado: informe_preview.pdf'),
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error descargando archivo: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      throw Exception('Respuesta sin URL o base64 de PDF');
    } catch (e) {
      // Propagar para que el caller haga fallback
      throw Exception('Error al generar PDF desde HTML: $e');
    }
  }

  Future<void> _descargarPdf(BuildContext context, int servicioId) async {
    try {
      //       print('🔵 Iniciando descarga de PDF para servicio: $servicioId');

      // Obtener token
      final token = await AuthService.getBearerToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      // Llamar al endpoint de generación de PDF
      final response = await http.post(
        Uri.parse(
          '${ServerConfig.instance.apiRoot()}/informes/generar_pdf.php',
        ),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode({'servicio_id': servicioId}),
      );

      //       print('🔵 Response status: ${response.statusCode}');
      //       print('🔵 Response content-type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        // Verificar si es un PDF
        if (contentType.contains('application/pdf') ||
            response.bodyBytes.length > 100 &&
                String.fromCharCodes(response.bodyBytes.take(5)) == '%PDF-') {
          //           print('✅ PDF recibido, tamaño: ${response.bodyBytes.length} bytes');

          // Crear nombre del archivo
          final nombreArchivo =
              'informe_servicio_${servicioId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

          // Descargar usando el servicio de descarga
          await dl.saveBytes(
            nombreArchivo,
            response.bodyBytes,
            mimeType: 'application/pdf',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('PDF descargado exitosamente')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Intentar parsear como JSON
          try {
            final data = json.decode(response.body);

            if (data['success'] == true) {
              final archivo = data['data']['archivo'];
              final rutaPublica =
                  archivo['ruta_publica'] ??
                  archivo['url_completa'] ??
                  archivo['ruta'];

              if (rutaPublica != null && rutaPublica.isNotEmpty) {
                final urlCompleta = _construirUrlCompleta(rutaPublica);
                final nombreArchivo =
                    archivo['nombre_archivo'] ?? 'informe_$servicioId.pdf';

                await DownloadService.descargarArchivo(
                  nombreArchivo: nombreArchivo,
                  rutaPublica: urlCompleta,
                  onSuccess: (mensaje) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PDF descargado exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  onError: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                );
              }
            } else {
              throw Exception(data['message'] ?? 'Error desconocido');
            }
          } catch (e) {
            throw Exception('Respuesta inesperada del servidor');
          }
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      //       print('❌ Error en _descargarPdf: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _construirUrlCompleta(String rutaPublica) {
    if (rutaPublica.startsWith('http')) return rutaPublica;
    final baseUrl = ServerConfig.instance.apiRoot();
    return '$baseUrl/$rutaPublica';
  }

  Widget _buildPreviewError(String message) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
