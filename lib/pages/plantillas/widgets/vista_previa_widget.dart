import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../servicios/services/servicios_api_service.dart';
import '../../firmas/services/firmas_service.dart';
import '../../firmas/models/firma_model.dart';
import '../providers/plantilla_provider.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/pages/plantillas/utils/html_preview_utils.dart';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import '../../servicios/services/download_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../../servicios/models/servicio_model.dart';
import '../../servicios/models/equipo_model.dart';
import '../../clientes/models/cliente_model.dart';

class VistaPreviaWidget extends StatefulWidget {
  final String? initialOrdenServicio;

  const VistaPreviaWidget({super.key, this.initialOrdenServicio});

  @override
  State<VistaPreviaWidget> createState() => _VistaPreviaWidgetState();
}

class _VistaPreviaWidgetState extends State<VistaPreviaWidget> {
  final TextEditingController _ordenServicioController =
      TextEditingController();
  String? _htmlPreview;
  WebViewController? _webViewController;
  bool _isWebViewReady = false;
  bool _isDownloading = false;
  int? _servicioIdDePreview;
  ServicioModel? _lastService;
  EquipoModel? _lastEquipment;
  ClienteModel? _lastClient;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrdenServicio != null) {
      _ordenServicioController.text = widget.initialOrdenServicio!;
    }
    _initWebView();
  }

  @override
  void dispose() {
    _ordenServicioController.dispose();
    super.dispose();
  }

  // ========================================
  // INICIALIZAR WEBVIEW
  // ========================================
  void _initWebView() {
    _webViewController = WebViewController();

    // En web, setJavaScriptMode no está implementado y lanza UnimplementedError.
    // JavaScript ya está habilitado por defecto en el plugin web.
    if (!kIsWeb) {
      try {
        _webViewController!.setJavaScriptMode(JavaScriptMode.unrestricted);
      } catch (e) {
        debugPrint('⚠️ setJavaScriptMode no soportado: $e');
      }
    }

    try {
      _webViewController!
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
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
      debugPrint('⚠️ Configuración de WebView parcial en web: $e');
    }
  }

  Future<void> _generatePreview() async {
    final ordenText = _ordenServicioController.text.trim();
    if (ordenText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el número de servicio (o_servicio)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = context.read<PlantillaProvider>();
    final htmlContent = provider.currentPlantilla?.contenidoHtml;

    if (htmlContent == null || htmlContent.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes escribir contenido HTML en el editor primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await provider.generatePreviewByOrden(ordenText);

      final result = provider.previewResult;
      final error = provider.previewError;

      if (error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      if (result != null) {
        final htmlProcesado = result['html_procesado'];

        //         print('🔵 Resultado de preview:');
        //         print('🔵 Keys disponibles: ${result.keys}');
        //         print('🔵 html_procesado length: ${htmlProcesado?.toString().length ?? 0}');

        if (htmlProcesado is String && htmlProcesado.isNotEmpty) {
          // Intentar obtener firmas por servicio asociado al número ingresado
          FirmaModel? firmaParaInyectar;
          try {
            // Buscar servicios y elegir el que coincida EXACTO con el o_servicio ingresado
            final r = await ServiciosApiService.listarServicios(
              pagina: 1,
              limite: 50,
              buscar: ordenText,
            );
            final servicios = (r['servicios'] as List<dynamic>);
            dynamic servicioMatch;
            for (final s in servicios) {
              try {
                final oServ = (s as dynamic).oServicio?.toString();
                if (oServ == ordenText) {
                  servicioMatch = s;
                  break;
                }
              } catch (_) {
                try {
                  final oServ =
                      (s as Map<String, dynamic>)['o_servicio']?.toString();
                  if (oServ == ordenText) {
                    servicioMatch = s;
                    break;
                  }
                } catch (_) {}
              }
            }

            final target =
                servicioMatch ??
                (servicios.isNotEmpty ? servicios.first : null);

            if (target != null) {
              int? servicioId;
              try {
                servicioId = (target as dynamic).id as int?;
              } catch (_) {
                try {
                  servicioId = int.tryParse(
                    (target as Map<String, dynamic>)['id'].toString(),
                  );
                } catch (_) {}
              }

              if (servicioId != null) {
                // Guardamos el servicio_id resuelto para reutilizarlo en la descarga
                _servicioIdDePreview = servicioId;
                final resFirmas = await FirmasService.obtenerFirmasPorServicio(
                  servicioId,
                );
                if (resFirmas['success'] == true) {
                  final firmas = (resFirmas['firmas'] as List<FirmaModel>);
                  if (firmas.isNotEmpty) {
                    firmaParaInyectar = firmas.first;
                  }
                }
              }

              // Guardar modelos para previsualización local futura
              try {
                _lastService = (target is ServicioModel) ? target : ServicioModel.fromJson(target as Map<String, dynamic>);
              } catch (e) {
                debugPrint('⚠️ No se pudo convertir target a ServicioModel: $e');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error al buscar servicio o firmas: $e');
          }

          var htmlCompleto = await HtmlPreviewUtils.prepareHtmlCompleto(
            htmlProcesado,
            firmaParaInyectar,
            modulo: provider.currentPlantilla?.modulo ?? 'servicios',
            model: _lastService,
            equipment: _lastEquipment,
            client: _lastClient,
            availableTags: provider.tagCategories,
          );


          // Cargar HTML en el WebView
          if (_webViewController != null) {
            await _webViewController!.loadHtmlString(htmlCompleto);
            setState(() => _htmlPreview = htmlCompleto);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Vista previa generada exitosamente'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: No se recibió HTML procesado. Keys: ${result.keys.join(", ")}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      //       print('❌ Error en _generatePreview: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  /// Refresca la vista previa usando la lógica LOCAL del TagEngine.
  /// Esto permite ver cambios en el HTML sin llamar al backend de nuevo.
  Future<void> _localRefresh() async {
    final provider = context.read<PlantillaProvider>();
    final htmlContent = provider.currentPlantilla?.contenidoHtml;

    if (htmlContent == null || htmlContent.trim().isEmpty) return;

    // Obtener firma anterior si existe
    FirmaModel? firma;
    if (_servicioIdDePreview != null) {
       final resFirmas = await FirmasService.obtenerFirmasPorServicio(_servicioIdDePreview!);
       if (resFirmas['success'] == true) {
         final firmas = (resFirmas['firmas'] as List<FirmaModel>);
         if (firmas.isNotEmpty) firma = firmas.first;
       }
    }

    // Usar HtmlPreviewUtils que ya integra el TagEngine
    final htmlCompleto = await HtmlPreviewUtils.prepareHtmlCompleto(
      htmlContent,
      firma,
      modulo: provider.currentPlantilla?.modulo ?? 'servicios',
      model: _lastService,
      equipment: _lastEquipment,
      client: _lastClient,
      availableTags: provider.tagCategories,
    );

    if (_webViewController != null) {
      await _webViewController!.loadHtmlString(htmlCompleto);
      setState(() => _htmlPreview = htmlCompleto);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Vista previa actualizada (Local)'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ========================================
  // DESCARGAR PDF POR o_servicio (sin usar diálogo)
  // ========================================
  Future<void> _descargarPdfPorOrden() async {
    final ordenText = _ordenServicioController.text.trim();
    if (ordenText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el número de servicio (o_servicio)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      // Resolver servicio_id a partir del o_servicio ingresado
      int? servicioId;
      try {
        final r = await ServiciosApiService.listarServicios(
          pagina: 1,
          limite: 50,
          buscar: ordenText,
        );
        final servicios = (r['servicios'] as List<dynamic>);
        dynamic servicioMatch;
        for (final s in servicios) {
          try {
            final oServ = (s as dynamic).oServicio?.toString();
            if (oServ == ordenText) {
              servicioMatch = s;
              break;
            }
          } catch (_) {
            try {
              final oServ =
                  (s as Map<String, dynamic>)['o_servicio']?.toString();
              if (oServ == ordenText) {
                servicioMatch = s;
                break;
              }
            } catch (_) {}
          }
        }
        final target =
            servicioMatch ?? (servicios.isNotEmpty ? servicios.first : null);
        if (target != null) {
          try {
            servicioId = (target as dynamic).id as int?;
          } catch (_) {
            try {
              servicioId = int.tryParse(
                (target as Map<String, dynamic>)['id'].toString(),
              );
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo listar servicios: $e');
      }

      if (servicioId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró el servicio para ese o_servicio'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 1) Generar por servicio_id usando el mismo endpoint del detalle de servicio
      final token = await AuthService.getBearerToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': token,
      };

      final generarUri = Uri.parse(
        '${ServerConfig.instance.apiRoot()}/informes/generar_pdf.php',
      );
      final respGenerar = await http.post(
        generarUri,
        headers: headers,
        body: json.encode({'servicio_id': servicioId}),
      );

      // ¿Devolvió PDF directo?
      if (_esPdfResponse(respGenerar)) {
        await dl.saveBytes(
          'informe_$ordenText.pdf',
          respGenerar.bodyBytes,
          mimeType: 'application/pdf',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Archivo descargado')));
        return;
      }

      // ¿Devolvió JSON con ruta pública?
      if (respGenerar.statusCode == 200) {
        try {
          final data = json.decode(respGenerar.body) as Map<String, dynamic>;
          if (data['success'] == true) {
            final inner = (data['data'] as Map<String, dynamic>?);
            final rutaPublica =
                inner == null
                    ? null
                    : (inner['ruta_publica'] ??
                            inner['pdf_url'] ??
                            inner['url_pdf'])
                        ?.toString();
            if (rutaPublica != null && rutaPublica.isNotEmpty) {
              await DownloadService.descargarArchivo(
                nombreArchivo: 'informe_$ordenText.pdf',
                rutaPublica: rutaPublica,
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
          }
        } catch (e) {
          debugPrint('⚠️ Error parseando respuesta de generar_pdf: $e');
        }
      }

      // 2) Fallback: intentar vista_previa_pdf con servicio_id
      final previewUri = Uri.parse(
        '${ServerConfig.instance.apiRoot()}/informes/vista_previa_pdf.php',
      );
      final respPreview = await http.post(
        previewUri,
        headers: headers,
        body: json.encode({'servicio_id': servicioId}),
      );

      if (_esPdfResponse(respPreview)) {
        await dl.saveBytes(
          'informe_$ordenText.pdf',
          respPreview.bodyBytes,
          mimeType: 'application/pdf',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Archivo descargado')));
        return;
      }

      if (respPreview.statusCode == 200) {
        try {
          final data = json.decode(respPreview.body) as Map<String, dynamic>;
          if (data['success'] == true) {
            final inner = (data['data'] as Map<String, dynamic>?);
            final url =
                inner == null
                    ? null
                    : (inner['pdf_url'] ??
                            inner['url_pdf'] ??
                            inner['preview_url'] ??
                            inner['ruta_publica'])
                        ?.toString();
            if (url != null && url.isNotEmpty) {
              await DownloadService.descargarArchivo(
                nombreArchivo: 'informe_$ordenText.pdf',
                rutaPublica: url,
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

            final b64 = inner?['pdf_base64']?.toString();
            if (b64 != null && b64.isNotEmpty) {
              final bytes = base64Decode(b64);
              await dl.saveBytes(
                'informe_$ordenText.pdf',
                bytes,
                mimeType: 'application/pdf',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Archivo descargado')),
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Respuesta no JSON de vista_previa_pdf: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el PDF'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ========================================
  // DESCARGAR PDF DESDE EL MISMO HTML DE LA VISTA PREVIA
  // ========================================
  /// Genera y descarga un PDF usando el mismo HTML mostrado en la vista previa.
  /// Utiliza el endpoint `informes/vista_previa_pdf.php` enviando `contenido_html`.
  Future<void> _descargarPdfDesdeHtml() async {
    final htmlCompleto = _htmlPreview;
    if (htmlCompleto == null || htmlCompleto.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero genera la vista previa para descargar el mismo PDF',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final token = await AuthService.getBearerToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      // Construir payload incluyendo o_servicio y servicio_id si están disponibles
      final ordenText = _ordenServicioController.text.trim();
      final Map<String, dynamic> payload = {'contenido_html': htmlCompleto};
      if (ordenText.isNotEmpty) {
        payload['o_servicio'] = ordenText;
      }
      if (_servicioIdDePreview != null) {
        payload['servicio_id'] = _servicioIdDePreview;
      }

      final response = await http.post(
        Uri.parse(
          '${ServerConfig.instance.apiRoot()}/informes/vista_previa_pdf.php',
        ),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode({
          ...payload,
          // Solicitar explícitamente generación de PDF en este flujo
          'generar_pdf': true,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.statusCode}');
      }

      final contentType = response.headers['content-type'] ?? '';
      final isPdfContentType =
          contentType.contains('application/pdf') ||
          contentType.contains('application/octet-stream');
      final bytes = response.bodyBytes;
      final startsWithPdfMagic =
          bytes.length > 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';

      // Caso 1: backend devuelve el PDF binario directamente
      if (isPdfContentType || startsWithPdfMagic) {
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
        return;
      }

      // Caso 2: backend devuelve JSON con URL o base64
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Respuesta inesperada del servidor');
      }

      if (data['success'] != true) {
        throw Exception(
          data['message'] ?? 'No se pudo generar el PDF desde HTML',
        );
      }

      Map<String, dynamic>? inner =
          data['data'] is Map<String, dynamic>
              ? data['data'] as Map<String, dynamic>
              : null;

      String? pdfUrl =
          (data['pdf_url'] ??
                  data['url_pdf'] ??
                  data['url'] ??
                  data['preview_url'])
              ?.toString();
      String? rutaPublica =
          (data['ruta_publica'] ?? data['url_completa'] ?? data['ruta'])
              ?.toString();
      String? base64 =
          (data['pdf_base64'] ?? data['base64'] ?? data['contenido_base64'])
              ?.toString();

      if ((pdfUrl == null || pdfUrl.isEmpty) && inner != null) {
        pdfUrl =
            (inner['pdf_url'] ??
                    inner['url_pdf'] ??
                    inner['url'] ??
                    inner['preview_url'])
                ?.toString();
      }
      if ((rutaPublica == null || rutaPublica.isEmpty) && inner != null) {
        rutaPublica =
            (inner['ruta_publica'] ?? inner['url_completa'] ?? inner['ruta'])
                ?.toString();
      }
      if ((base64 == null || base64.isEmpty) && inner != null) {
        base64 =
            (inner['pdf_base64'] ??
                    inner['base64'] ??
                    inner['contenido_base64'])
                ?.toString();
      }

      // Caso: archivo anidado con ruta
      Map<String, dynamic>? archivo =
          data['archivo'] is Map<String, dynamic>
              ? data['archivo'] as Map<String, dynamic>
              : null;
      if (archivo == null &&
          inner != null &&
          inner['archivo'] is Map<String, dynamic>) {
        archivo = inner['archivo'] as Map<String, dynamic>;
      }
      if (archivo != null && (rutaPublica == null || rutaPublica.isEmpty)) {
        rutaPublica =
            (archivo['ruta_publica'] ??
                    archivo['url_completa'] ??
                    archivo['ruta'])
                ?.toString();
      }

      if (pdfUrl != null && pdfUrl.isNotEmpty) {
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

      if (rutaPublica != null && rutaPublica.isNotEmpty) {
        await DownloadService.descargarArchivo(
          nombreArchivo: 'informe_preview.pdf',
          rutaPublica: rutaPublica,
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

      if (base64 != null && base64.isNotEmpty) {
        final decoded = base64Decode(base64);
        await dl.saveBytes(
          'informe_preview.pdf',
          decoded,
          mimeType: 'application/pdf',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archivo descargado: informe_preview.pdf'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Sin fallback al generador legacy; asegurar que el PDF se produce desde el mismo HTML
      throw Exception('Respuesta sin URL ni base64 de PDF');

      throw Exception('Respuesta sin URL, base64 o bytes de PDF');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF desde HTML: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  bool _esPdfResponse(http.Response r) {
    final ct = r.headers['content-type']?.toLowerCase() ?? '';
    if (ct.contains('application/pdf')) return true;
    final b = r.bodyBytes;
    if (b.length >= 4) {
      final magic = String.fromCharCodes(b.sublist(0, 4));
      return magic == '%PDF';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<PlantillaProvider>().isGeneratingPreview;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista Previa del Informe',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa el número de servicio (o_servicio) para ver cómo quedará el informe con datos reales en base a la plantilla actual',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Input y botón
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ordenServicioController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Número de Servicio (o_servicio)',
                    hintText: 'Ej: 1-2025-000123',
                    prefixIcon: const Icon(Icons.receipt_long),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _generatePreview,
                icon:
                    isLoading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.preview),
                label: Text(isLoading ? 'Generando...' : 'Generar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
              if (_lastService != null) ...[
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Actualizar solo tags localmente (Más rápido)',
                  child: FilledButton.tonalIcon(
                    onPressed: isLoading ? null : _localRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refrescar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed:
                    (_isDownloading || isLoading)
                        ? null
                        : _descargarPdfDesdeHtml,
                icon:
                    _isDownloading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isDownloading ? 'Descargando...' : 'Descargar PDF',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  backgroundColor: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Vista previa con WebView
          Expanded(
            child:
                _htmlPreview != null
                    ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            _webViewController != null
                                ? WebViewWidget(controller: _webViewController!)
                                : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                      ),
                    )
                    : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.preview,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Vista Previa del Informe',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ingresa el número de servicio (o_servicio) y presiona "Generar"',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'para ver el informe con datos reales',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
