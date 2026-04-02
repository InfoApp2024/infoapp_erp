/// ============================================================================
/// ARCHIVO: servicio_detail_page.dart
///
/// PROPéSITO: Página de visualización detallada que:
/// - Muestra toda la información del servicio en modo solo lectura
/// - Presenta timeline de estados
/// - Muestra campos adicionales
/// - Permite acciones rápidas (editar, anular, compartir)
/// - Genera vista para impresión/PDF
///
/// USO: Se accede desde el botón ver (???) en la tabla o al hacer clic en una fila
/// FUNCIéN: Vista de solo lectura con presentación optimizada para consulta rápida y compartir información.
/// ============================================================================
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:infoapp/utils/net_error_messages.dart';

// Importar modelos y servicios
import '../models/servicio_model.dart';
import 'servicio_edit_page.dart';
import 'servicio_create_page.dart';
import '../servicio_edit_hub.dart';
import '../controllers/branding_controller.dart';
import 'package:infoapp/core/branding/theme_provider.dart';
import 'package:provider/provider.dart';
import '../services/campos_adicionales_api_service.dart';
import '../services/servicio_repuestos_api_service.dart' hide ApiResponse;
import '../services/servicios_api_service.dart';
import '../services/servicio_operaciones_api_service.dart';
import '../services/servicios_export_service.dart';
// Eliminamos el previsualizador en detalle y descargamos directamente
// import '../../plantillas/widgets/preview_informe_dialog.dart';
// Eliminado: usaremos llamada directa al endpoint de vista previa
import '../services/download_service.dart';
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import '../../plantillas/utils/html_preview_utils.dart';
import '../../plantillas/views/plantillas_list_view.dart';
import '../../firmas/services/firmas_service.dart';
import '../../firmas/models/firma_model.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../models/servicio_repuesto_model.dart';
import '../models/campo_adicional_model.dart'; // ? FIXED: Missing import
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../plantillas/models/plantilla_model.dart';
import '../../plantillas/widgets/template_selection_bottom_sheet.dart';
import '../widgets/umw/umw_service_summary.dart';
import '../models/operacion_model.dart';
import '../models/service_time_log_model.dart';
import '../models/servicio_staff_model.dart';

/// Página para visualizar los detalles completos de un servicio
class ServicioDetailPage extends StatefulWidget {
  final ServicioModel servicio;

  const ServicioDetailPage({super.key, required this.servicio});

  @override
  State<ServicioDetailPage> createState() => _ServicioDetailPageState();
}

class _ServicioDetailPageState extends State<ServicioDetailPage> {
  late ServicioModel _servicio;
  bool _isLoading = false;
  bool _isDownloadingPdf = false; // Loader especé­fico del icono PDF
  double _downloadProgress = 0.0; // Progreso visual en porcentaje

  // ? NUEVO: ThemeProvider para el branding
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _servicio = widget.servicio;
    _themeProvider.addListener(
      _onThemeChanged,
    ); // ? NUEVO: Escuchar cambios de tema
    _themeProvider.cargarConfiguracion(); // ? NUEVO: Cargar branding
    _cargarDatosCompletos(); // ? NUEVO: Cargar detalles enriquecidos
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged); // ? NUEVO: Limpiar listener
    super.dispose();
  }

  // ? NUEVO: Callback para cambios de tema
  void _onThemeChanged() {
    setState(() {});
  }

  // ? NUEVAS VARIABLES DE ESTADO
  bool _isLoadingDetalles = false;
  List<ServicioRepuestoModel> _repuestos = [];
  List<CampoAdicionalModel> _camposAdicionales = [];
  double _costoTotalRepuestos = 0.0;
  List<OperacionModel> _operaciones = [];
  List<ServiceTimeLogModel> _logsTiempo = [];
  List<ServicioStaffModel> _staff = [];
  FirmaModel? _firma;

  // ? NUEVO: Cargar todos los detalles
  Future<void> _cargarDatosCompletos() async {
    if (_servicio.id == null) return;

    setState(() => _isLoadingDetalles = true);

    try {
      // 1. Cargar Repuestos
      final repuestosFuture =
          ServicioRepuestosApiService.listarRepuestosDeServicio(
            servicioId: _servicio.id!,
            incluirDetallesItem: true,
          );

      // 2. Cargar Campos Adicionales
      final camposFuture = CamposAdicionalesApiService.obtenerCamposConValores(
        servicioId: _servicio.id!,
        modulo: 'Servicios',
      );

      // 3. Cargar Operaciones
      final operacionesFuture = ServicioOperacionesApiService.listarOperaciones(
        _servicio.id!,
      );

      // 4. Cargar Staff
      final staffFuture = ServiciosApiService.listarStaffDeServicio(
        _servicio.id!,
      );

      // 5. Cargar Logs de Tiempo
      final logsFuture = ServiciosApiService.obtenerLogsTiempo(_servicio.id!);

      // 6. Cargar Firma
      final firmaFuture = FirmasService.obtenerFirmasPorServicio(_servicio.id!);

      // Esperar todo junto
      final results = await Future.wait([
        repuestosFuture,
        camposFuture,
        operacionesFuture,
        staffFuture,
        logsFuture,
        firmaFuture,
      ]);

      if (mounted) {
        setState(() {
          // Repuestos
          final repuestosResp =
              results[0] as ApiResponse<ServicioRepuestosResponse>;
          if (repuestosResp.success && repuestosResp.data != null) {
            _repuestos = repuestosResp.data!.repuestos;
            _costoTotalRepuestos = repuestosResp.data!.costoTotal;
          }

          // Campos Adicionales
          _camposAdicionales =
              (results[1] as List<dynamic>).cast<CampoAdicionalModel>();

          // Operaciones
          _operaciones = results[2] as List<OperacionModel>;

          // Staff
          _staff = results[3] as List<ServicioStaffModel>;

          // Logs de Tiempo
          final logsResp =
              results[4] as ApiResponse<List<ServiceTimeLogModel>>;
          if (logsResp.isSuccess && logsResp.data != null) {
            _logsTiempo = logsResp.data!;
          }

          // Firma
          final resFirmas = results[5] as Map<String, dynamic>;
          if (resFirmas['success'] == true) {
            final dynamic rawFirmas = resFirmas['firmas'] ?? resFirmas['data'];
            if (rawFirmas is List && rawFirmas.isNotEmpty) {
              _firma = rawFirmas.first as FirmaModel;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando detalles enriquecidos: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDetalles = false);
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || !hexColor.startsWith('#') || hexColor.length != 7) {
      return Theme.of(context).colorScheme.outlineVariant;
    }
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return Theme.of(context).colorScheme.outlineVariant;
    }
  }

  IconData _getMaintenanceIcon(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'correctivo':
        return PhosphorIcons.wrench();
      case 'preventivo':
        return PhosphorIcons.calendar();
      case 'predictivo':
        return PhosphorIcons.chartLineUp();
      default:
        return PhosphorIcons.gear();
    }
  }

  Color _getColorTipoMantenimiento(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'correctivo':
        return Theme.of(context).colorScheme.error;
      case 'preventivo':
        return context.successColor;
      case 'predictivo':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return 'No establecida';
    try {
      final fechaObj = DateTime.parse(fecha);
      return '${fechaObj.day}/${fechaObj.month}/${fechaObj.year}';
    } catch (e) {
      return fecha.length > 10 ? fecha.substring(0, 10) : fecha;
    }
  }

  Future<void> _editarServicio() async {
    final resultado = await Navigator.push<ServicioModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ServicioEditPage(servicio: _servicio),
      ),
    );

    if (resultado != null) {
      setState(() {
        _servicio = resultado;
      });
      _mostrarExito('Servicio actualizado exitosamente');
    }
  }

  // ? NUEVO: Navegación a versión V2 (Hub)
  Future<void> _editarServicioV2() async {
    final resultado = await Navigator.push<ServicioModel>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider(
              create: (_) => BrandingController()..cargarBranding(),
              child: ServicioEditHub(servicio: _servicio),
            ),
      ),
    );

    if (resultado != null) {
      setState(() {
        _servicio = resultado;
      });
      _mostrarExito('Servicio actualizado exitosamente (V2)');
    }
  }

  /// Duplicar servicio - Crear una copia con datos básicos
  Future<void> _duplicarServicio() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Crear copia del servicio para duplicar
      final servicioParaDuplicar = _servicio.crearCopiaParaDuplicar();

      // Navegar a la página de creación con los datos pre-poblados
      final servicioCreado = await Navigator.push<ServicioModel>(
        context,
        MaterialPageRoute(
          builder:
              (context) => ServicioCreatePage(
                servicioParaDuplicar: servicioParaDuplicar,
              ),
        ),
      );

      if (servicioCreado != null) {
        _mostrarExito(
          'Servicio duplicado exitosamente como #${servicioCreado.oServicio}',
        );
      }
    } catch (e) {
      _mostrarError('Error al duplicar servicio: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Compartir servicio - Mostrar opciones de compartir
  Future<void> _compartirServicio() async {
    try {
      // Mostrar opciones de compartir
      final opcion = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => _buildOpcionesCompartir(),
      );

      if (opcion != null) {
        if (opcion == 'completo') {
          await _copiarTextoCompletoAlPortapapeles();
        } else if (opcion == 'resumen') {
          await _copiarResumenAlPortapapeles();
        } else if (opcion == 'whatsapp') {
          await _enviarAWhatsApp();
        } else if (opcion == 'copiar') {
          await _copiarAlPortapapeles();
        }
      }
    } catch (e) {
      _mostrarError('Error al compartir: $e');
    }
  }

  /// Construir opciones para compartir (actualizado)
  Widget _buildOpcionesCompartir() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Té­tulo
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Información del Servicio ${_servicio.numeroServicioFormateado}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'La información se copiará al portapapeles para que puedas pegarla donde necesites',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Opciones de compartir
            _buildOpcionCompartir(
              icono: PhosphorIcons.fileText(),
              titulo: 'Información Completa',
              descripcion: 'Copiar todos los detalles del servicio',
              onTap: () => Navigator.pop(context, 'completo'),
            ),
            const SizedBox(height: 12),
            _buildOpcionCompartir(
              icono: PhosphorIcons.clipboardText(),
              titulo: 'Resumen',
              descripcion: 'Copiar información básica',
              onTap: () => Navigator.pop(context, 'resumen'),
            ),
            const SizedBox(height: 12),
            _buildOpcionCompartir(
              icono: PhosphorIcons.whatsappLogo(),
              titulo: 'WhatsApp',
              descripcion: 'Enviar detalle directamente por WhatsApp',
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
            const SizedBox(height: 20),

            // Botón cancelar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _themeProvider
                          .primaryColor, // ? ACTUALIZADO: Color del branding
                  side: BorderSide(
                    color: _themeProvider.primaryColor,
                  ), // ? ACTUALIZADO: Color del branding
                ),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir una opción de compartir
  Widget _buildOpcionCompartir({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _themeProvider.primaryColor.withOpacity(
                  0.1,
                ), // ? ACTUALIZADO: Color del branding
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icono,
                color: _themeProvider.primaryColor,
              ), // ? ACTUALIZADO: Color del branding
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(),
              size: 16,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Generar el texto completo del servicio (Reutilizado para copiar y WhatsApp)
  Future<String> _generarTextoDetalleCompleto() async {
    // Texto base con campos estándar del formulario
    final base = _servicio.generarTextoParaCompartir();

    // Anexar campos adicionales (si el servicio tiene ID)
    String adicionales = '';
    if (_servicio.id != null) {
      final campos = await CamposAdicionalesApiService.obtenerCamposConValores(
        servicioId: _servicio.id!,
        modulo: 'Servicios',
      );

      if (campos.isNotEmpty) {
        final b = StringBuffer();
        b.writeln();
        b.writeln('📋 Campos adicionales');
        b.writeln('-' * 30);
        for (final campo in campos) {
          final valorStr =
              CamposAdicionalesApiService.formatearValorParaTabla(campo);
          if (valorStr.isNotEmpty) {
            b.writeln('• ${campo.nombreCampo}: $valorStr');
          }
        }
        adicionales = b.toString();
      }
    }

    // Anexar sección de repuestos del servicio
    String repuestosTexto = '';
    if (_servicio.id != null) {
      try {
        final resp = await ServicioRepuestosApiService.listarRepuestosDeServicio(
          servicioId: _servicio.id!,
          incluirDetallesItem: true,
        );

        if (resp.success && resp.data != null && resp.data!.repuestos.isNotEmpty) {
          final r = StringBuffer();
          r.writeln();
          r.writeln('🛠️ Repuestos');
          r.writeln('-' * 30);
          for (final rep in resp.data!.repuestos) {
            final nombre = rep.itemNombreCompleto;
            final cantidad = rep.cantidad;
            final unit = rep.costoUnitario;
            final total = rep.costoTotal;
            r.writeln(
              '• $nombre — x$cantidad · U: \$${unit.toStringAsFixed(2)} · Total: \$${total.toStringAsFixed(2)}',
            );
          }
          r.writeln(
            'Total repuestos: \$${resp.data!.costoTotal.toStringAsFixed(2)}',
          );
          repuestosTexto = r.toString();
        }
      } catch (e) {
        debugPrint('Error cargando repuestos para compartir: $e');
      }
    }

    // Anexar sección de personal asignado al servicio
    String staffTexto = '';
    if (_servicio.id != null) {
      try {
        final staff = await ServiciosApiService.listarStaffDeServicio(
          _servicio.id!,
        );
        if (staff.isNotEmpty) {
          final s = StringBuffer();
          s.writeln();
          s.writeln('👷 Personal del servicio');
          s.writeln('-' * 30);
          for (final persona in staff) {
            final nombre = persona.fullName;
            final cargo = persona.positionTitle;
            if (cargo != null && cargo.isNotEmpty) {
              s.writeln('• $nombre ($cargo)');
            } else {
              s.writeln('• $nombre');
            }
          }
          staffTexto = s.toString();
        }
      } catch (e) {
        debugPrint('Error cargando staff para compartir: $e');
      }
    }

    return '$base$adicionales$repuestosTexto$staffTexto';
  }

  /// Copiar texto completo al portapapeles
  Future<void> _copiarTextoCompletoAlPortapapeles() async {
    try {
      final texto = await _generarTextoDetalleCompleto();
      await Clipboard.setData(ClipboardData(text: texto));
      _mostrarExito('Información completa copiada al portapapeles');
    } catch (e) {
      _mostrarError('Error al copiar: $e');
    }
  }

  /// Enviar detalle por WhatsApp
  Future<void> _enviarAWhatsApp() async {
    try {
      final texto = await _generarTextoDetalleCompleto();
      final textEncoded = Uri.encodeComponent(texto);
      
      // Determinar si es PC o Móvil
      bool isPC = kIsWeb;
      if (!kIsWeb) {
        isPC = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      }
      
      // Construir URL según plataforma
      final url = isPC 
          ? 'https://web.whatsapp.com/send?text=$textEncoded'
          : 'https://wa.me/?text=$textEncoded';
          
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: Si no puede lanzar la URL específica (ej: no hay app), intentar wa.me genérico
        final fallbackUri = Uri.parse('https://wa.me/?text=$textEncoded');
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _mostrarError('No se pudo abrir WhatsApp: $e');
    }
  }

  /// Copiar resumen al portapapeles
  Future<void> _copiarResumenAlPortapapeles() async {
    try {
      final resumen = _servicio.generarResumenCorto();
      await Clipboard.setData(ClipboardData(text: resumen));
      _mostrarExito('Resumen copiado al portapapeles');
    } catch (e) {
      _mostrarError('Error al copiar: $e');
    }
  }

  /// Copiar al portapapeles (función existente - sin cambios)
  Future<void> _copiarAlPortapapeles() async {
    try {
      final texto = _servicio.generarTextoParaCompartir();
      await Clipboard.setData(ClipboardData(text: texto));
      _mostrarExito('Información copiada al portapapeles');
    } catch (e) {
      _mostrarError('Error al copiar: $e');
    }
  }

  /// Mostrar diálogo de confirmación para duplicar
  Future<void> _mostrarConfirmacionDuplicar() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Duplicar Servicio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Deseas duplicar el servicio ${_servicio.numeroServicioFormateado}?',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.info(),
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Se copiará:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Información del equipo\n'
                        '• Tipo de mantenimiento\n'
                        '• Orden del cliente\n'
                        '• Funcionario autorizado',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.warningColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.warningColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.warningCircle(),
                            color: context.warningColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Se generará nuevo:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: context.warningColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Número de servicio\n'
                        '• Fecha de ingreso\n'
                        '• Estado inicial',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.warningColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _themeProvider
                          .primaryColor, // ? ACTUALIZADO: Color del branding
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Duplicar'),
              ),
            ],
          ),
    );

    if (confirmacion == true) {
      await _duplicarServicio();
    }
  }

  void _mostrarError(String mensaje) {
    // Si el error es sobre falta de plantillas, mostramos opción para crear
    if (mensaje.toLowerCase().contains('no hay plantillas') ||
        mensaje.toLowerCase().contains('plantillas disponibles')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8), // Mayor duración
          action: SnackBarAction(
            label: 'Crear',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PlantillasListView(),
                ),
              );
            },
          ),
        ),
      );
    } else {
      NetErrorMessages.showMessage(context, mensaje, success: false);
    }
  }

  void _mostrarExito(String mensaje) {
    NetErrorMessages.showMessage(context, mensaje, success: true);
  }

  /// Mostrar selector de plantilla y proceder con la descarga
  Future<void> _seleccionarPlantillaYDescargar() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TemplateSelectionBottomSheet(
            clienteId: _servicio.clienteId,
            onSelected: (template) {
              _descargarInformeDesdePreview(template: template);
            },
          ),
    );
  }

  // Descarga directa del informe usando la misma lógica de la vista previa
  Future<void> _descargarInformeDesdePreview({Plantilla? template}) async {
    if (_servicio.id == null) return;
    try {
      setState(() {
        _isDownloadingPdf = true;
        _downloadProgress = 0.05; // inicio
      });

      // 1) Intentar vista previa SIN token (para evitar fallo por autenticación)
      final previewUri = Uri.parse(
        '${ServerConfig.instance.apiRoot()}/informes/vista_previa_pdf.php',
      );

      // Siempre intentar con token si existe para que el backend resuelva datos del usuario/empresa
      final token = await AuthService.getBearerToken();
      Map<String, String> baseHeaders = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': token,
      };

      final Map<String, dynamic> payload = {'servicio_id': _servicio.id!};
      if (template?.id != null) {
        payload['plantilla_id'] = template!.id;
      }

      http.Response response = await http.post(
        previewUri,
        headers: baseHeaders,
        body: json.encode(payload),
      );

      // ? Validar errores del backend (ej. 400 Bad Request por falta de plantillas)
      if (response.statusCode != 200) {
        String errorMsg =
            'Error al generar vista previa (${response.statusCode})';
        try {
          final errBody = json.decode(response.body);
          if (errBody is Map && errBody['message'] != null) {
            errorMsg = errBody['message'];
          }
        } catch (_) {
          // Si falla JSON, intentar usar el cuerpo si es corto (ej. error PHP fatal)
          if (response.body.isNotEmpty && response.body.length < 500) {
            errorMsg = response.body;
          }
        }
        throw Exception(errorMsg);
      }

      // Validar si el backend devolvió éxito falso con status 200
      try {
        if (!_esPdfResponse(response)) {
          final bodyJson = json.decode(response.body);
          if (bodyJson is Map && bodyJson['success'] == false) {
            throw Exception(
              bodyJson['message'] ?? 'Error desconocido en vista previa',
            );
          }
        }
      } catch (e) {
        if (e is FormatException && !_esPdfResponse(response)) {
          // No es JSON ni PDF -> Probablemente error fatal PHP
          throw Exception(
            'Respuesta inválida del servidor: ${response.body.substring(0, min(200, response.body.length))}...',
          );
        }
        if (e is Exception && e.toString().contains('Error desconocido')) {
          rethrow;
        }
      }

      // Si el endpoint devolvió PDF directo, guardar sin parsear JSON
      if (response.statusCode == 200 && _esPdfResponse(response)) {
        final nombre = 'informe_${_servicio.oServicio ?? _servicio.id}.pdf';
        await dl.saveBytes(
          nombre,
          response.bodyBytes,
          mimeType: 'application/pdf',
        );
        if (mounted) setState(() => _downloadProgress = 1.0);
        return;
      }

      if (response.statusCode == 200 && _respuestaOk(response)) {
        final data = _parseJson(response.body);
        if (mounted) setState(() => _downloadProgress = 0.25);
        final inner = (data['data'] as Map<String, dynamic>?);

        // 2a) Priorizar HTML procesado por el servidor (ya tiene todos los tags resueltos)
        String? htmlProcesado =
            inner == null
                ? null
                : (inner['html_procesado'] ??
                        inner['html'] ??
                        inner['html_resultado'])
                    ?.toString();

        // Solo si el servidor no devolvió nada procesado, intentamos usar el del template (fallback legacy)
        if (htmlProcesado == null || htmlProcesado.trim().isEmpty) {
          htmlProcesado = template?.contenidoHtml;
        }

        if (htmlProcesado != null && htmlProcesado.trim().isNotEmpty) {
          // Preparar HTML igual que en la vista previa: sanitizar, branding, firmas y tags de usuario
          FirmaModel? firma;
          try {
            final resFirmas = await FirmasService.obtenerFirmasPorServicio(
              _servicio.id!,
            );
            if (resFirmas['success'] == true) {
              final list = resFirmas['firmas'] as List<FirmaModel>?;
              if (list != null && list.isNotEmpty) {
                firma = list.first;
              }
            }
          } catch (_) {}

          final htmlCompleto = await HtmlPreviewUtils.prepareHtmlCompleto(
            htmlProcesado,
            firma,
          );
          if (mounted) setState(() => _downloadProgress = 0.45);

          // Incluir Authorization desde el inicio para que el backend resuelva encabezados/tags
          Map<String, String> hdr = {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': token,
          };
          final bodyMap = <String, dynamic>{
            'contenido_html': htmlCompleto,
            'generar_pdf': true,
          };
          if ((_servicio.oServicio ?? '').toString().isNotEmpty) {
            bodyMap['o_servicio'] = _servicio.oServicio;
          } else if (_servicio.id != null) {
            bodyMap['servicio_id'] = _servicio.id;
          }
          var body2 = json.encode(bodyMap);
          http.Response r2 = await http.post(
            previewUri,
            headers: hdr,
            body: body2,
          );
          if (mounted) setState(() => _downloadProgress = 0.6);

          // ? Validar errores del backend en 2da petición
          if (r2.statusCode != 200) {
            String errorMsg = 'Error al generar PDF final (${r2.statusCode})';
            try {
              final errBody = json.decode(r2.body);
              if (errBody is Map && errBody['message'] != null) {
                errorMsg = errBody['message'];
              }
            } catch (_) {
              if (r2.body.isNotEmpty && r2.body.length < 500) {
                errorMsg = r2.body;
              }
            }
            throw Exception(errorMsg);
          }

          // Validar éxito en r2
          try {
            if (!_esPdfResponse(r2)) {
              final j = json.decode(r2.body);
              if (j is Map && j['success'] == false) {
                throw Exception(j['message'] ?? 'Error en generación final');
              }
            }
          } catch (e) {
            if (e is FormatException && !_esPdfResponse(r2)) {
              throw Exception(
                'Respuesta inválida (2): ${r2.body.substring(0, min(200, r2.body.length))}...',
              );
            }
            if (e is Exception &&
                (e.toString().contains('Error en generación') ||
                    e.toString().contains('Respuesta inválida'))) {
              rethrow;
            }
          }

          // Si devuelve PDF directo
          if (r2.statusCode == 200 && _esPdfResponse(r2)) {
            final nombre = 'informe_${_servicio.oServicio ?? _servicio.id}.pdf';
            await dl.saveBytes(
              nombre,
              r2.bodyBytes,
              mimeType: 'application/pdf',
            );
            if (mounted) setState(() => _downloadProgress = 1.0);
            return;
          }

          // Si devuelve JSON con url/base64
          if (r2.statusCode == 200 && _respuestaOk(r2)) {
            final d2 = _parseJson(r2.body);
            final i2 = (d2['data'] as Map<String, dynamic>?);
            final url2 =
                i2 == null
                    ? null
                    : (i2['pdf_url'] ??
                            i2['url_pdf'] ??
                            i2['preview_url'] ??
                            i2['ruta_publica'])
                        ?.toString();
            if (url2 != null && url2.isNotEmpty) {
              await DownloadService.descargarArchivo(
                nombreArchivo:
                    'informe_${_servicio.oServicio ?? _servicio.id}.pdf',
                rutaPublica: url2,
                onProgress: (p) {
                  if (!mounted) return;
                  // p en 0..1 si hay content-length; si no, mantener progreso actual
                  if (p.isFinite && !p.isNaN) {
                    setState(
                      () =>
                          _downloadProgress = (0.6 + (p * 0.4)).clamp(0.0, 1.0),
                    );
                  }
                },
                onError:
                    (e) => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e))),
              );
              if (mounted) setState(() => _downloadProgress = 1.0);
              return;
            }
            final b64_2 = i2?['pdf_base64']?.toString();
            if (b64_2 != null && b64_2.isNotEmpty) {
              final bytes2 = base64Decode(b64_2);
              await dl.saveBytes(
                'informe_${_servicio.oServicio ?? _servicio.id}.pdf',
                bytes2,
                mimeType: 'application/pdf',
              );
              if (mounted) setState(() => _downloadProgress = 1.0);
              return;
            }
          }
          // Si por alguna razón no salió nada, continuamos con los campos originales abajo
        }

        // 2b) Si no hay HTML procesado, usar las vías tradicionales de url/base64
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
            nombreArchivo: 'informe_${_servicio.oServicio ?? _servicio.id}.pdf',
            rutaPublica: url,
            onProgress: (p) {
              if (!mounted) return;
              if (p.isFinite && !p.isNaN) {
                setState(
                  () => _downloadProgress = (0.6 + (p * 0.4)).clamp(0.0, 1.0),
                );
              }
            },
            onError:
                (e) => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e))),
          );
          if (mounted) setState(() => _downloadProgress = 1.0);
          return;
        }

        final base64 = inner?['pdf_base64']?.toString();
        if (base64 != null && base64.isNotEmpty) {
          final bytes = base64Decode(base64);
          await dl.saveBytes(
            'informe_${_servicio.oServicio ?? _servicio.id}.pdf',
            bytes,
            mimeType: 'application/pdf',
          );
          if (mounted) setState(() => _downloadProgress = 1.0);
          return;
        }
      }

      // 3) No usar generador legacy para asegurar identidad con la vista previa
      throw Exception(
        'No se pudo generar el PDF. El servidor no devolvió un archivo válido ni un mensaje de error claro.',
      );
    } catch (e) {
      _mostrarError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  bool _respuestaOk(http.Response r) {
    try {
      final data = _parseJson(r.body);
      return data['success'] == true;
    } catch (_) {
      return false;
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

  Map<String, dynamic> _parseJson(String body) {
    return json.decode(body) as Map<String, dynamic>;
  }

  Future<void> _descargarPdfSimple(int servicioId) async {
    try {
      final uri = Uri.parse(
        '${ServerConfig.instance.apiRoot()}/informes/generar_pdf.php',
      );
      Map<String, String> headers = {'Content-Type': 'application/json'};
      final body = json.encode({'servicio_id': servicioId});

      // Intentar sin token
      http.Response response = await http.post(
        uri,
        headers: headers,
        body: body,
      );
      // Si falla, intentar con token si existe
      if (response.statusCode != 200 || !_respuestaOk(response)) {
        final token = await AuthService.getBearerToken();
        if (token != null) {
          response = await http.post(
            uri,
            headers: {...headers, 'Authorization': token},
            body: body,
          );
        }
      }

      if (response.statusCode != 200) {
        String errorMsg = 'Error del servidor: ${response.statusCode}';
        try {
          final errBody = json.decode(response.body);
          if (errBody is Map && errBody['message'] != null) {
            errorMsg = errBody['message'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }

      // ¿Devolvió PDF directo?
      if (_esPdfResponse(response)) {
        final nombre = 'informe_${_servicio.oServicio ?? servicioId}.pdf';
        await dl.saveBytes(
          nombre,
          response.bodyBytes,
          mimeType: 'application/pdf',
        );
        return;
      }

      final data = _parseJson(response.body);
      if (data['success'] != true) {
        throw Exception(
          data['message'] ?? 'No se pudo generar el PDF del servicio',
        );
      }

      final inner = (data['data'] as Map<String, dynamic>?);
      final rutaPublica =
          inner == null
              ? null
              : (inner['ruta_publica'] ?? inner['pdf_url'] ?? inner['url_pdf'])
                  ?.toString();
      if (rutaPublica == null || rutaPublica.isEmpty) {
        throw Exception('Respuesta sin URL del PDF');
      }

      await DownloadService.descargarArchivo(
        nombreArchivo: 'informe_${_servicio.oServicio ?? servicioId}.pdf',
        rutaPublica: rutaPublica,
        onError: (e) => _mostrarError(e),
      );
    } catch (e) {
      _mostrarError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  bool get _esServicioBloqueado {
    if (_servicio.estaAnulado) return true;
    if (_servicio.estaFinalizado) return true;

    // Heuré­stica de nombre por si falta fecha de finalización
    final nombre = _servicio.estadoNombre?.toUpperCase() ?? '';
    if ([
      'FINALIZADO',
      'TERMINADO',
      'CERRADO',
      'ENTREGADO',
    ].any((k) => nombre.contains(k))) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar con nuevas funcionalidades
      appBar: AppBar(
        title: Row(
          children: [
            // ? NUEVO: Logo del branding
            AppLogo(
              width: 28,
              height: 28,
              backgroundColor: Colors.white.withOpacity(0.9),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Servicio #${_servicio.oServicio ?? 'N/A'}')),
          ],
        ),
        backgroundColor:
            _themeProvider.primaryColor, // ? ACTUALIZADO: Color del branding
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_esServicioBloqueado &&
              PermissionStore.instance.can('servicios', 'actualizar')) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editarServicioV2, // Navega al Hub V2 por defecto
              tooltip: 'Editar servicio',
            ),
          ],
          if (_servicio.id != null)
            IconButton(
              icon:
                  _isDownloadingPdf
                      ? SizedBox(
                        width: 24,
                        height: 24,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              value:
                                  (_downloadProgress > 0 &&
                                          _downloadProgress < 1)
                                      ? _downloadProgress
                                      : null,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            if (_downloadProgress > 0 && _downloadProgress < 1)
                              Text(
                                '${(_downloadProgress * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (_downloadProgress >= 1.0)
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                          ],
                        ),
                      )
                      : const Icon(Icons.picture_as_pdf),
              onPressed:
                  _isDownloadingPdf ? null : _seleccionarPlantillaYDescargar,
              tooltip: 'Informe',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar servicio',
            onSelected: (value) {
              ServiciosExportService.exportarServicios(
                servicios: [_servicio],
                formato: value,
                camposAdicionales: const [],
                onSuccess:
                    (m) => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(m),
                        backgroundColor: context.successColor,
                      ),
                    ),
                onError:
                    (e) => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e))),
              );
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(value: 'csv', child: Text('CSV')),
                  PopupMenuItem(value: 'excel', child: Text('Excel')),
                  PopupMenuItem(value: 'pdf', child: Text('PDF')),
                ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'duplicate':
                  _mostrarConfirmacionDuplicar();
                  break;
                case 'share':
                  _compartirServicio();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 16),
                        SizedBox(width: 8),
                        Text('Duplicar Servicio'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 16),
                        SizedBox(width: 8),
                        Text('Compartir'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),

      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header principal
                    _buildHeaderPrincipal(),
                    const SizedBox(height: 16),

                    // ? MODERNIZACIÓN V2: Resumen Ejecutivo UMW
                    if (!_isLoadingDetalles)
                      UmwServiceSummary(
                        servicio: _servicio,
                        operaciones: _operaciones,
                        staff: _staff,
                        repuestos: _repuestos,
                        firma: _firma,
                        logsTiempo: _logsTiempo,
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Información básica
                    _buildSeccionInformacionBasica(),
                    const SizedBox(height: 24),

                    // ? NUEVO: Actividad Realizada
                    _buildSeccionActividad(),
                    if (_servicio.actividadNombre != null ||
                        _servicio.actividadId != null)
                      const SizedBox(height: 24),

                    // Detalles técnicos
                    _buildSeccionDetallesTecnicos(),
                    const SizedBox(height: 24),

                    // ? NUEVO: Personal Asignado
                    if (_isLoadingDetalles)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[

                      // ? NUEVO: Repuestos
                      _buildSeccionRepuestos(),
                      if (_repuestos.isNotEmpty) const SizedBox(height: 24),

                      // ? NUEVO: Campos Adicionales
                      _buildSeccionCamposAdicionales(),
                      if (_camposAdicionales.isNotEmpty)
                        const SizedBox(height: 24),
                    ],

                    // Estado y fechas
                    _buildSeccionEstadoYFechas(),
                    const SizedBox(height: 24),

                    // Información adicional si existe
                    if (_servicio.estaAnulado) ...[
                      _buildSeccionInformacionAdicional(),
                      const SizedBox(height: 24),
                    ],

                    // Acciones rápidas
                    _buildSeccionAcciones(),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeaderPrincipal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _themeProvider.primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _themeProvider.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getMaintenanceIcon(_servicio.tipoMantenimiento),
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servicio #${_servicio.oServicio ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _servicio.estadoNombre ?? 'Sin estado',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _servicio.tipoMantenimiento?.toUpperCase() ??
                      'TIPO NO ESPECIFICADO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (_servicio.estaAnulado)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'ANULADO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionInformacionBasica() {
    return _buildSeccionCard(
      titulo: 'Información Básica',
      icono: Icons.info_outline,
      children: [
        _buildInfoRow(
          'Cliente',
          _servicio.clienteNombre ?? _servicio.nombreEmp ?? 'No especificado',
        ),
        _buildInfoRow(
          'Orden del Cliente',
          _servicio.ordenCliente ?? 'No especificada',
        ),
        _buildInfoRow(
          'Fecha de Ingreso',
          _formatearFecha(_servicio.fechaIngreso),
        ),
        if (_servicio.equipoNombre != null)
          _buildInfoRow('Equipo', _servicio.equipoNombre!),
        if (_servicio.placa != null) _buildInfoRow('Placa', _servicio.placa!),
        if (_servicio.nombreEmp != null &&
            _servicio.nombreEmp != _servicio.clienteNombre)
          _buildInfoRow('Empresa Equipo', _servicio.nombreEmp!),
      ],
    );
  }

  Widget _buildSeccionDetallesTecnicos() {
    return _buildSeccionCard(
      titulo: 'Detalles Técnicos',
      icono: Icons.precision_manufacturing,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getColorTipoMantenimiento(_servicio.tipoMantenimiento),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getMaintenanceIcon(_servicio.tipoMantenimiento),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _servicio.tipoMantenimiento?.toUpperCase() ??
                        'NO ESPECIFICADO',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_servicio.tieneRepuestos) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.successColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.build_circle, color: context.successColor),
                const SizedBox(width: 8),
                Text(
                  'Se suministraron repuestos',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.successColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeccionEstadoYFechas() {
    return _buildSeccionCard(
      titulo: 'Estado y Fechas',
      icono: Icons.flag,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _parseColor(_servicio.estadoColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _parseColor(_servicio.estadoColor).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _parseColor(_servicio.estadoColor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _servicio.estadoNombre ?? 'Sin estado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _themeProvider.primaryColor,
                  ),
                ),
              ),
              Text(
                'Para cambiar estado, usar Editar',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        if (_servicio.estaFinalizado) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            'Fecha de Finalización',
            _formatearFecha(_servicio.fechaFinalizacion),
          ),
        ],
      ],
    );
  }

  Widget _buildSeccionInformacionAdicional() {
    return _buildSeccionCard(
      titulo: 'Información Adicional',
      icono: Icons.info,
      children: [
        if (_servicio.estaAnulado && _servicio.razon != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Servicio Anulado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Razón: ${_servicio.razon}',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ? NUEVAS SECCIONES DE UI

  Widget _buildSeccionActividad() {
    if (_servicio.actividadNombre == null && _servicio.actividadId == null) {
      return const SizedBox.shrink();
    }

    // 1. Gating por permisos: Ver en modulo 'servicios_actividades'
    final store = PermissionStore.instance;
    final canView = store.can('servicios_actividades', 'ver');
    final canList = store.can('servicios_actividades', 'listar');

    if (!canView) return const SizedBox.shrink();

    // 2. Si puede ver pero no listar, mostrar mensaje de restricción
    if (!canList) {
      return _buildSeccionCard(
        titulo: 'Actividad Realizada',
        icono: PhosphorIcons.clipboardText(),
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.lockKey(),
                color: Colors.grey.shade400,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No tienes permisos para ver el detalle de la actividad.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return _buildSeccionCard(
      titulo: 'Actividad Realizada',
      icono: PhosphorIcons.clipboardText(),
      children: [
        Text(
          _servicio.actividadNombre ?? 'Actividad ID: ${_servicio.actividadId}',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildSeccionRepuestos() {
    // 1. Gating por permisos: Ver en modulo 'servicios_repuestos'
    final store = PermissionStore.instance;
    final canView = store.can('servicios_repuestos', 'ver');
    final canList = store.can('servicios_repuestos', 'listar');

    if (!canView) return const SizedBox.shrink();

    // 2. Si puede ver pero no listar, mostrar mensaje de restricción
    if (!canList) {
      return _buildSeccionCard(
        titulo: 'Repuestos Suministrados',
        icono: PhosphorIcons.wrench(),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.lockKey(),
                  color: Colors.grey.shade400,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No tienes permisos para ver el detalle de repuestos.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_repuestos.isEmpty) return const SizedBox.shrink();

    return _buildSeccionCard(
      titulo: 'Repuestos Suministrados',
      icono: PhosphorIcons.wrench(),
      children: [
        ..._repuestos.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.itemNombreCompleto,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${r.cantidad} uds x \$${r.costoUnitario.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '\$${r.costoTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Total Repuestos: ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
            Text(
              '\$${_costoTotalRepuestos.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _themeProvider.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeccionCamposAdicionales() {
    // 1. Gating por permisos: Ver en modulo 'campos_adicionales'
    // Nota: Si el usuario tiene acceso al servicio, generalmente ve los campos,
    // pero agregamos el check especé­fico por consistencia si se requiere modulo aparte.
    // Si 'campos_adicionales' se maneja muy estricto, usar:
    final store = PermissionStore.instance;
    if (!store.can('campos_adicionales', 'ver') &&
        !store.can('campos_adicionales', 'listar')) {
      // Si no tiene permiso explé­cito, asumimos que NO ve la sección
      // A MENOS que la lógica de negocio diga que ver el servicio implica ver sus campos.
      // Para ser consistentes con la solicitud: check de permiso.
      return const SizedBox.shrink();
    }

    if (_camposAdicionales.isEmpty) return const SizedBox.shrink();

    return _buildSeccionCard(
      titulo: 'Información Adicional',
      icono: PhosphorIcons.puzzlePiece(),
      children:
          _camposAdicionales.map((campo) {
            final valorStr =
                CamposAdicionalesApiService.formatearValorParaTabla(campo);
            if (valorStr.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campo.nombreCampo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valorStr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSeccionAcciones() {
    final store = PermissionStore.instance;
    // Permisos para acciones especificas
    final canEdit = store.can('servicios', 'actualizar'); // Editar
    final canCreate = store.can('servicios', 'crear'); // Duplicar

    return _buildSeccionCard(
      titulo: 'Acciones',
      icono: PhosphorIcons.handPointing(),
      children: [
        // Primera fila: Editar (V2) y Duplicar
        Row(
          children: [
            if (!_servicio.estaAnulado && canEdit) ...[
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(PhosphorIcons.pencilSimple()),
                  label: const Text('Editar'), // Default es V2
                  onPressed: _editarServicioV2, // Navega al Hub V2
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themeProvider.primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (canCreate)
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(PhosphorIcons.copy()),
                  label: const Text('Duplicar'),
                  onPressed: _mostrarConfirmacionDuplicar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themeProvider.primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),

        // Botón Fallback: Editor Clásico (V1)
        if (!_servicio.estaAnulado && canEdit) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Usar Editor Clásico (Versión Anterior)'),
              onPressed: _editarServicio, // Navega a V1 legacy
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
        // Segunda fila: Compartir
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(PhosphorIcons.shareNetwork()),
            label: const Text('Compartir'),
            onPressed: _compartirServicio,
            style: OutlinedButton.styleFrom(
              foregroundColor: _themeProvider.primaryColor,
              side: BorderSide(color: _themeProvider.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionCard({
    required String titulo,
    required IconData icono,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _themeProvider.primaryColor.withOpacity(
            0.3,
          ), // ? ACTUALIZADO: Color del branding
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icono,
                color: _themeProvider.primaryColor,
                size: 24,
              ), // ? ACTUALIZADO: Color del branding
              const SizedBox(width: 12),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      _themeProvider
                          .primaryColor, // ? ACTUALIZADO: Color del branding
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
