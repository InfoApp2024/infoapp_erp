/// ============================================================================
/// ARCHIVO: servicio_form.dart
///
/// PROPÓSITO: Widget de formulario reutilizable que:
/// - Centraliza la lógica de formularios para crear/editar
/// - Gestiona validaciones comunes
/// - Maneja el estado del formulario
/// - Integra todos los campos y widgets necesarios
/// - Se puede usar tanto para crear como editar
///
/// USO: Componente interno usado por ServicioCreatePage y ServicioEditPage
/// FUNCIÓN: Componente base reutilizable que contiene toda la lógica común de formularios para evitar duplicación de código.
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:infoapp/pages/servicios/workflow/estado_workflow_service.dart';
import 'package:infoapp/pages/servicios/workflow/estado_workflow_models.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Importar widgets específicos del formulario
import 'package:infoapp/pages/servicios/forms/widgets/campo_numero_servicio.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_cliente.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_autorizado_por.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_equipo.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_tipo_mantenimiento.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_centro_costo.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campos_adicionales.dart';
import 'package:infoapp/pages/servicios/services/fotos_service.dart';
import 'package:infoapp/pages/servicios/fotos_servicio_page.dart';

// Importar modelos y servicios
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';
import 'package:infoapp/pages/servicios/models/equipo_model.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';
import 'package:infoapp/pages/servicios/widgets/actividad_selector_widget.dart';
import 'package:infoapp/pages/servicios/services/actividades_service.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:infoapp/pages/inspecciones/services/inspecciones_api_service.dart';
import 'package:infoapp/pages/inspecciones/pages/inspeccion_detalle_page.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';

/// Formulario reutilizable para crear y editar servicios
class ServicioForm extends StatefulWidget {
  final ServicioModel? servicio; // null = crear, no null = editar
  final Function(ServicioModel) onSaved;
  final Function(String)? onError;
  final bool isEditing;
  final bool enabled;
  final GlobalKey<CamposAdicionalesServiciosState>?
  camposAdicionalesKey; // ? CORREGIDO
  final ActividadesService? actividadesService; // ? NUEVO
  final int? actividadSeleccionadaId; // ? NUEVO
  final Function(int?)? onActividadChanged; // ? NUEVO
  // ? NUEVO: Callbacks para sincronizar con el padre
  final VoidCallback? onInitialized;
  final VoidCallback? onCamposAdicionalesLoaded;
  // ? NUEVO: Notificar al padre cuando el contenido del formulario cambia
  final VoidCallback? onChanged;
  // ? NUEVO: Notificar transiciones disponibles
  final Function(List<WorkflowTransicionDef>)? onTransitionsLoaded;
  // ? NUEVO: Callback para validar repuestos antes de avanzar
  final Future<bool> Function()? onValidateRepuestos;

  const ServicioForm({
    super.key,
    this.servicio,
    required this.onSaved,
    this.onError,
    this.isEditing = false,
    this.enabled = true,
    this.camposAdicionalesKey, // ? NUEVO
    this.actividadesService, // ? NUEVO
    this.actividadSeleccionadaId, // ? NUEVO
    this.onActividadChanged, // ? NUEVO
    this.onInitialized,
    this.onCamposAdicionalesLoaded,
    this.onChanged,
    this.onTransitionsLoaded,
    this.onValidateRepuestos,
  });

  @override
  State<ServicioForm> createState() => ServicioFormState();
}

// Hacer pública la clase para acceso desde otras partes
class ServicioFormState extends State<ServicioForm> {
  // Permitir que el padre dispare el guardado del formulario
  void guardarFormulario() {
    if (_formKey.currentState?.validate() ?? false) {
      // Llamar a onSaved con el modelo actualizado
      widget.onSaved(_construirModeloServicio());
    }
  }

  // Permitir que el padre dispare el avance de estado desde la tarjeta superior
  void avanzarEstado([WorkflowTransicionDef? transicion]) {
    _avanzarEstado(transicion);
  }

  Future<void> _avanzarEstado([WorkflowTransicionDef? transicion]) async {
    if (_isChangingState || !widget.enabled) return;

    // Si no se pasa transición, intentar obtener la primera disponible o mostrar error
    if (transicion == null) {
      _mostrarError('No se especificó una transición válida.');
      return;
    }

    // 1. Confirmar Acción
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(transicion.nombre ?? 'Confirmar Cambio de Estado'),
            content: Text(
              'Desea cambiar el estado del servicio a "${transicion.to}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isChangingState = true);

    try {
      final res = await ServiciosApiService.cambiarEstadoServicio(
        servicioId: _servicioActual!.id!,
        nuevoEstadoId: transicion.toId ?? 0,
        estadoDestinoNombre: transicion.to,
        triggerCode: transicion.triggerCode,
      );

      if (res.isSuccess) {
        _mostrarExito('Estado actualizado correctamente a ${transicion.to}');

        // Refrescar datos si es posible
        final resServicio = await ServiciosApiService.obtenerServicio(
          _servicioActual!.id!,
        );
        if (resServicio.data != null) {
          if (mounted) {
            setState(() {
              _servicioOverride = resServicio.data;
            });
            // Recargar transiciones para el nuevo estado
            await _cargarTransicionesDisponibles();
          }
        }

        // Notificar cambios al padre si existe callback
        if (widget.onChanged != null) {
          widget.onChanged!();
        }
      } else {
        _mostrarError(res.error ?? 'Error al cambiar estado');
      }
    } catch (e) {
      _mostrarError('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() => _isChangingState = false);
      }
    }
  }

  // ? NUEVO: Métodos públicos requeridos por ServicioEditPage
  bool validate() {
    return _formKey.currentState?.validate() ?? false;
  }

  void save() {
    _formKey.currentState?.save();
  }

  ServicioModel get servicioActual => _construirModeloServicio();

  final _formKey = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _ordenClienteController = TextEditingController();
  final TextEditingController _oServicioController = TextEditingController();
  final TextEditingController _fechaFinalizacionController =
      TextEditingController();

  // Estados del formulario
  bool _isLoading = false;
  final bool _isSubmitting = false;
  bool _isChangingState = false; // ? NUEVO: Para cambios de estado
  bool _suministraronRepuestos = false;
  bool _isInitializing =
      true; // ? NUEVO: Para evitar falsos positivos durante carga inicial
  bool _camposAdicionalesLoaded =
      false; // ? NUEVO: Flag específico para campos adicionales

  // Datos del formulario
  DateTime _fechaIngreso = DateTime.now();

  int? _autorizadoPor;
  EquipoModel? _equipoSeleccionado;
  String? _tipoMantenimiento;
  String? _centroCosto;
  EstadoModel? _estadoInicial;
  DateTime? _fechaFinalizacion;
  int? _clienteId; // ? NUEVO: ID del cliente seleccionado
  // Para nmero de servicio
  bool _puedeEditarNumero = false;

  // ? NUEVO: Override local del servicio para actualizaciones sin reconstruir widget
  ServicioModel? _servicioOverride;
  ServicioModel? get _servicioActual => _servicioOverride ?? widget.servicio;

  // ? NUEVO: Cache para evitar revalidaciones innecesarias
  int? _ultimoEquipoValidado;
  int? _ultimaActividadValidada;

  // ? NUEVO: Estado local para actividad seleccionada (para validación inmediata)
  int? _actividadSeleccionadaId;

  // Callbacks para UI

  // ? NUEVO: Estado local para validacin de fotos
  int _cantidadFotos = 0;

  // ? Helper para triggers de fotos
  Future<void> _actualizarContadorFotos() async {
    if (widget.servicio?.id == null) return;

    try {
      // Usamos FotosService para obtener el conteo real
      final conteo = await FotosService.contarFotosPorTipo(
        widget.servicio!.id!,
      );
      if (mounted) {
        setState(() {
          _cantidadFotos = conteo['total'] ?? 0;
        });
      }
    } catch (e) {}
  }

  // ? Helper para abrir modal de fotos
  // Esta era la declaración antigua que estaba duplicada o vacía, la reemplazamos con la implementación correcta
  // y nos aseguramos de no tener otra más abajo.
  Future<void> _mostrarModalFotos() async {
    if (widget.servicio?.id == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FotosServicioPage(
              servicioId: widget.servicio!.id!,
              servicio: widget.servicio!,
              readOnly: false, // Permitir subir fotos
            ),
      ),
    );

    // Al volver, actualizamos el contador
    await _actualizarContadorFotos();
  }

  // ? Helper para abrir modal de fotos
  /// ? NUEVO: Solicitar razón de anulación
  Future<String?> _solicitarRazonAnulacion() async {
    final razonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(PhosphorIcons.warning(), color: Colors.red.shade600),
                const SizedBox(width: 8),
                const Text('Anular Servicio'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.info(),
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Justificación requerida. Esta acción NO se puede revertir.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Motivo de la anulación:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: razonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describa por qué se anula el servicio...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La razón es obligatoria';
                        }
                        if (value.trim().length < 40) {
                          return 'Mínimo 40 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: razonController,
                      builder: (context, value, _) {
                        final length = value.text.length;
                        return Text(
                          '$length/40 caracteres',
                          style: TextStyle(
                            fontSize: 11,
                            color: length >= 40 ? Colors.green : Colors.red,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, razonController.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar Anulación'),
              ),
            ],
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    _inicializarFormulario();
    // ? NO configurar listeners aquí - se configuran después de la inicialización
  }

  /// ? NUEVO: Configurar listeners para detectar cambios en controladores de texto
  void _setupChangeListeners() {
    _ordenClienteController.addListener(_onOrdenClienteChanged);
    _oServicioController.addListener(_onOServicioChanged);
    _fechaFinalizacionController.addListener(_onFechaFinalizacionChanged);
  }

  // Wrappers para listeners de controladores
  void _onOrdenClienteChanged() => _onFieldChanged('OrdenCliente');
  void _onOServicioChanged() => _onFieldChanged('OServicio');
  void _onFechaFinalizacionChanged() => _onFieldChanged('FechaFinalizacion');

  void _onFieldChanged([String source = 'Unknown']) {
    // ? Ignorar cambios durante la inicialización o carga
    if (_isInitializing || _isLoading || widget.onChanged == null) {
      return;
    }

    widget.onChanged!();
  }

  // ? NUEVO: Actualizar formulario si el servicio cambia externamente
  @override
  void didUpdateWidget(covariant ServicioForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.servicio != oldWidget.servicio && widget.servicio != null) {
      // Si el servicio cambió desde fuera, reseteamos el override
      _servicioOverride = null;
      _cargarDatosExistentes().then((_) => _cargarTransicionesDisponibles());
    }
  }

  Future<void> _inicializarFormulario() async {
    setState(() => _isLoading = true);

    try {
      // Si es edición, cargar datos existentes
      if (widget.isEditing && widget.servicio != null) {
        await _cargarDatosExistentes();
      } else {
        // Si es nuevo, verificar número
        await _verificarNumeroServicio();
      }
    } catch (e) {
      _manejarError('Error inicializando formulario: $e');
    } finally {
      // ? CRTICO: Configurar listeners ANTES de setState
      _setupChangeListeners();

      // ? Primero actualizar solo _isLoading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // ? CRÍTICO: Esperar al siguiente frame para marcar inicialización completa
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Cargar transiciones después de que el modelo esté listo
        await _cargarTransicionesDisponibles();

        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      });

      // Notificar que el formulario terminó su inicialización
      if (widget.onInitialized != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onInitialized!.call();
        });
      }
    }
  }

  Future<void> _cargarDatosExistentes() async {
    final servicio = widget.servicio!;

    // Cargar datos básicos
    _ordenClienteController.text = servicio.ordenCliente ?? '';
    _oServicioController.text = servicio.oServicio?.toString() ?? '';
    _fechaIngreso = servicio.fechaIngresoDate ?? DateTime.now();
    // Cargar fecha de finalización si existe
    if (servicio.fechaFinalizacion != null) {
      try {
        _fechaFinalizacion = DateTime.parse(servicio.fechaFinalizacion!);
        _fechaFinalizacionController.text = _formatearFecha(
          _fechaFinalizacion!,
        );
      } catch (e) {
        //         print('Error parseando fecha de finalización: $e');
      }
    }
    _autorizadoPor = servicio.autorizadoPor;
    _tipoMantenimiento = servicio.tipoMantenimiento;
    _centroCosto = servicio.centroCosto;
    _clienteId = servicio.clienteId; // ? NUEVO

    // ? NUEVO: Cargar valor de repuestos
    _suministraronRepuestos = servicio.suministraronRepuestos ?? false;

    // Cargar equipo si existe
    if (servicio.idEquipo != null) {
      try {
        final equipos = await ServiciosApiService.listarEquipos();
        _equipoSeleccionado = equipos.firstWhere(
          (equipo) => equipo.id == servicio.idEquipo,
          orElse: () => equipos.first,
        );
      } catch (e) {
        //         print('?? Error cargando equipo: $e');
      }
    }

    // Resetear flag de carga de campos adicionales ya que se recargarn
    _camposAdicionalesLoaded = false;
    setState(() {});
  }

  /// ? NUEVO: Cargar transiciones disponibles desde el workflow service
  Future<void> _cargarTransicionesDisponibles() async {
    if (_servicioActual == null) return;

    final estadoActual = _servicioActual!.estadoNombre ?? 'Pendiente';
    final workflowService = EstadoWorkflowService();

    try {
      // Asegurar que esté cargado (preferiblemente desde backend)
      await workflowService.ensureLoaded();

      final acciones = workflowService.getAvailableTransitions(estadoActual);

      if (widget.onTransitionsLoaded != null) {
        widget.onTransitionsLoaded!(acciones);
      }
    } catch (e) {}
  }

  Future<void> _verificarNumeroServicio() async {
    try {
      final resultado = await ServiciosApiService.verificarPrimerServicio();
      if (resultado.isSuccess && resultado.data != null) {
        if (mounted) {
          setState(() {
            _puedeEditarNumero = resultado.data!['es_primer_servicio'] ?? false;
            _oServicioController.text =
                resultado.data!['siguiente_numero'].toString();
          });
        }
      }
    } catch (e) {
      _manejarError('Error verificando número de servicio: $e');
    }
  }

  bool _validarCamposRequeridos() {
    // ? NUEVA VALIDACIÓN: Para edición, verificar que existe el ID
    if (widget.isEditing && widget.servicio?.id == null) {
      _mostrarError('Error: El servicio no tiene un ID válido para actualizar');
      return false;
    }

    if (_autorizadoPor == null) {
      _mostrarError('Seleccione quien autoriza el servicio');
      return false;
    }

    if (_equipoSeleccionado == null) {
      _mostrarError('Seleccione un equipo');
      return false;
    }

    if (_tipoMantenimiento == null) {
      _mostrarError('Seleccione el tipo de mantenimiento');
      return false;
    }

    return true;
  }

  /// ? NUEVO: Validar si existe inspección activa con la actividad pendiente
  Future<void> _validarInspeccionActiva(int? equipoId, int? actividadId) async {
    if (!mounted) return;

    if (widget.isEditing) return;
    if (equipoId == null || actividadId == null) return;

    // Resetear validacin forzada para depuracin (comentar linea siguiente en prod)
    // _ultimoEquipoValidado = null;

    if (_ultimoEquipoValidado == equipoId &&
        _ultimaActividadValidada == actividadId) {
      return;
    }

    try {
      final resultado = await InspeccionesApiService.listarInspecciones(
        equipoId: equipoId,
        limite: 5,
      );

      final inspecciones = resultado['inspecciones'] as List<dynamic>;

      // ? MODIFICADO: No filtrar por estado. Revisar TODAS las recientes.
      // Si tiene una actividad pendiente, es relevante, sin importar si la inspección dice "Finalizada".
      final activas = inspecciones;

      if (!mounted) return;

      for (final inspeccion in activas) {
        if (inspeccion.id == null) continue;

        final detalle = await InspeccionesApiService.obtenerInspeccion(
          inspeccion.id!,
        );

        if (detalle.actividades == null) continue;

        try {
          final actividadPendiente = detalle.actividades!.firstWhere((a) {
            final match = a.actividadId == actividadId;
            final noAutorizada = a.autorizada != true;
            final sinServicio =
                a.servicioId == null; // ? CLAVE: No tiene servicio asignado

            // Solo alertar si coincide, NO está autorizada, y NO tiene servicio asignado
            return match && noAutorizada && sinServicio;
          });

          if (mounted) {
            _mostrarAlertaInspeccion(
              detalle,
              actividadPendiente.actividadNombre,
            );
          }

          _ultimoEquipoValidado = equipoId;
          _ultimaActividadValidada = actividadId;
          return;
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarAlertaInspeccion(dynamic inspeccion, String? actividadNombre) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Actividad Pendiente en Inspección'),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'El equipo tiene la inspeccin '),
                      TextSpan(
                        text: '#${inspeccion.oInspe ?? inspeccion.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' activa con la actividad '),
                      TextSpan(
                        text: '"${actividadNombre ?? 'Seleccionada'}"',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' pendiente de autorizacin.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    'Se recomienda gestionar la inspeccin antes de crear un servicio directo para evitar duplicidad.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ignorar y Continuar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Cerrar dilogo
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => InspeccionDetallePage(
                            inspeccionId: inspeccion.id!,
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text('Ir a Inspección'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  ServicioModel _construirModeloServicio() {
    // ? VALIDACIÓN: Para edición, el ID debe existir
    if (widget.isEditing && widget.servicio?.id == null) {
      throw Exception('Error: No se puede actualizar un servicio sin ID');
    }

    return ServicioModel(
      id: widget.servicio?.id,
      oServicio: int.tryParse(_oServicioController.text.trim()),
      fechaIngreso: _fechaIngreso.toIso8601String().split('T')[0],
      fechaFinalizacion: _fechaFinalizacion?.toIso8601String().split('T')[0],
      ordenCliente: _ordenClienteController.text.trim(),
      autorizadoPor: _autorizadoPor ?? widget.servicio?.funcionarioId ?? 0,
      tipoMantenimiento:
          _tipoMantenimiento ?? widget.servicio?.tipoMantenimiento ?? '',
      centroCosto: _centroCosto ?? widget.servicio?.centroCosto,
      idEquipo: _equipoSeleccionado?.id ?? widget.servicio?.idEquipo,
      bloqueoRepuestos: _servicioActual?.bloqueoRepuestos,
      clienteId: _clienteId ?? widget.servicio?.clienteId,
      funcionarioId: _autorizadoPor ?? widget.servicio?.funcionarioId,
      suministraronRepuestos: _suministraronRepuestos,
    );
  }

  void _manejarError(String mensaje) {
    if (widget.onError != null) {
      widget.onError!(mensaje);
    } else {
      _mostrarError(mensaje);
    }
  }

  void _mostrarError(String mensaje) {
    if (context.mounted) {
      try {
        NetErrorMessages.showMessage(context, mensaje, success: false);
      } catch (_) {}
    }
  }

  void _mostrarExito(String mensaje) {
    if (context.mounted) {
      try {
        NetErrorMessages.showMessage(context, mensaje, success: true);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando formulario...'),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // =============================================
          //    SECCIÓN: INFORMACIÓN BÁSICA
          // =============================================
          _buildSeccionInformacionBasica(),

          const SizedBox(height: 32),

          // =============================================
          //    SECCIÓN: DETALLES DEL SERVICIO
          // =============================================
          _buildSeccionDetallesServicio(),

          const SizedBox(height: 32),

          // Los botones de accin se renderizarn fuera del formulario en la pgina
        ],
      ),
    );
  }

  Widget _buildSeccionInformacionBasica() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de seccin
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: context.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Información Básica',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Campo de Cliente
          CampoCliente(
            clienteSeleccionado: _clienteId,
            onChanged: (cliente) {
              if (_clienteId == cliente?.id) return;

              setState(() {
                _clienteId = cliente?.id;
                _equipoSeleccionado = null;
                _autorizadoPor = null;
              });
              _onFieldChanged('CampoCliente');
            },
            enabled: widget.enabled && !_isSubmitting && !widget.isEditing,
            validator:
                (valor) => valor == null ? 'El cliente es obligatorio' : null,
          ),
          const SizedBox(height: 16),

          // Fecha de Ingreso
          _buildCampoFecha(),
          const SizedBox(height: 16),

          // Número de Servicio
          if (!widget.isEditing) ...[
            CampoNumeroServicio(
              controller: _oServicioController,
              puedeEditar: _puedeEditarNumero && !widget.isEditing,
            ),
            const SizedBox(height: 16),
          ],

          // Orden del Cliente
          _buildCampoOrdenCliente(),

          // Fecha de Finalización (solo edición)
          if (widget.isEditing) ...[
            const SizedBox(height: 10),
            _buildCampoFechaFinalizacion(),
          ],
        ],
      ),
    );
  }

  Widget _buildCampoFechaFinalizacion() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.event_available,
          color: Theme.of(context).primaryColor,
        ),
        title: const Text('Fecha de Finalización'),
        subtitle: Text(
          _fechaFinalizacion != null
              ? _formatearFecha(_fechaFinalizacion!)
              : 'No establecida',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_fechaFinalizacion != null)
              IconButton(
                icon: Icon(Icons.clear, color: Colors.red.shade400),
                onPressed:
                    (widget.enabled && !_isSubmitting)
                        ? () {
                          setState(() {
                            _fechaFinalizacion = null;
                            _fechaFinalizacionController.clear();
                          });
                        }
                        : null,
                tooltip: 'Limpiar fecha',
              ),
            const Icon(Icons.edit),
          ],
        ),
        onTap:
            (widget.enabled && !_isSubmitting)
                ? _seleccionarFechaFinalizacion
                : null,
      ),
    );
  }

  /// ✨ NUEVO: Construir campo de repuestos (solo para edición)

  Widget _buildSeccionDetallesServicio() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de seccin
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings,
                  color: context.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Detalles del Servicio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Campo Equipo (Movido arriba para que el filtro de funcionario funcione mejor)
          CampoEquipo(
            equipoSeleccionado: _equipoSeleccionado?.id,
            clienteId: _clienteId,
            onChanged: (equipo) {
              if (_equipoSeleccionado?.id == equipo?.id) return;

              setState(() => _equipoSeleccionado = equipo);
              if (equipo != null && _actividadSeleccionadaId != null) {
                _validarInspeccionActiva(equipo.id, _actividadSeleccionadaId!);
              }
              _onFieldChanged('CampoEquipo');
            },
            enabled: widget.enabled && !_isSubmitting && !widget.isEditing,
            validator: (valor) => valor == null ? 'Seleccione un equipo' : null,
          ),
          const SizedBox(height: 16),

          // Campo Autorizado por - Con Permisos Escalonados
          Builder(
            builder: (context) {
              final store = PermissionStore.instance;
              // 1. VER: Controla visibilidad
              final canView = store.can('servicios_autorizado_por', 'ver');
              // 2. LISTAR: Controla edición/interacción (si puede ver pero no listar, es read-only)
              final canEdit = store.can('servicios_autorizado_por', 'listar');

              if (!canView) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampoAutorizadoPor(
                    autorizadoPor: _autorizadoPor,
                    onChanged: (valor) {
                      if (_autorizadoPor == valor) {
                        return; // ? Validar cambio real
                      }
                      setState(() => _autorizadoPor = valor);
                      _onFieldChanged(
                        'CampoAutorizadoPor',
                      ); // ✅ Notificar cambio
                    },
                    // Se deshabilita si no tiene permiso 'listar' o si el form est enviando/deshabilitado
                    enabled: widget.enabled && !_isSubmitting && canEdit,
                    empresa:
                        _equipoSeleccionado?.nombreEmpresa ??
                        widget.servicio?.nombreEmp,
                    clienteId: _clienteId, // ? NUEVO: Filtro jerrquico
                    validator:
                        (valor) =>
                            valor == null ? 'Seleccione quien autoriza' : null,
                  ),
                  if (!canEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.lockKey(),
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Lectura solamente (sin permiso de gestión)',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16), // Aumentado de 10 a 16
          // Campo Tipo de Mantenimiento (Con Permisos Escalonados)
          Builder(
            builder: (context) {
              final store = PermissionStore.instance;
              final canView = store.can('servicios_tipo_mantenimiento', 'ver');
              final canList = store.can(
                'servicios_tipo_mantenimiento',
                'listar',
              );
              final canCreate = store.can(
                'servicios_tipo_mantenimiento',
                'crear',
              );
              final canDelete = store.can(
                'servicios_tipo_mantenimiento',
                'eliminar',
              );

              if (!canView) return const SizedBox.shrink();

              return CampoTipoMantenimiento(
                tipoSeleccionado: _tipoMantenimiento,
                onChanged: (valor) {
                  if (_tipoMantenimiento == valor) return;
                  setState(() => _tipoMantenimiento = valor);
                  _onFieldChanged('CampoTipoMantenimiento');
                },
                enabled: widget.enabled && !_isSubmitting && canList,
                canCreate: canCreate,
                canDelete: canDelete,
                validator:
                    (valor) => valor == null ? 'Seleccione un tipo' : null,
              );
            },
          ),
          const SizedBox(height: 16),

          // NUEVO: Campo Centro de Costo (Con Permisos Escalonados)
          Builder(
            builder: (context) {
              final store = PermissionStore.instance;
              final canView = store.can('servicios_centro_costo', 'ver');
              final canList = store.can('servicios_centro_costo', 'listar');
              final canCreate = store.can('servicios_centro_costo', 'crear');
              final canDelete = store.can('servicios_centro_costo', 'eliminar');

              if (!canView) return const SizedBox.shrink();

              return CampoCentroCosto(
                centroSeleccionado: _centroCosto,
                onChanged: (centro) {
                  if (_centroCosto == centro) return;
                  setState(() => _centroCosto = centro);
                  _onFieldChanged('CampoCentroCosto');
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Seleccione un centro de costo';
                  }
                  return null;
                },
                enabled: widget.enabled && !_isSubmitting && canList,
                canCreate: canCreate,
                canDelete: canDelete,
              );
            },
          ),
          const SizedBox(height: 16),

          // ✅ NUEVO: Selector de actividades (después del selector de equipos)
          if (widget.actividadesService != null &&
              !widget.servicio!.estaAnulado) ...[
            const SizedBox(height: 16), // Aumentado de 10 a 16
            _buildSelectorActividades(),
          ],

          // ...
        ],
      ),
    );
  }

  Widget _buildCampoFecha() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.calendar_today,
          color: Theme.of(context).primaryColor,
        ),
        title: const Text('Fecha de Ingreso'),
        subtitle: Text(
          '${_fechaIngreso.day}/${_fechaIngreso.month}/${_fechaIngreso.year}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.edit),
        onTap: (widget.enabled && !_isSubmitting) ? _seleccionarFecha : null,
      ),
    );
  }

  Widget _buildCampoOrdenCliente() {
    return TextFormField(
      controller: _ordenClienteController,
      inputFormatters: [UpperCaseTextFormatter()],
      decoration: InputDecoration(
        labelText: 'Orden del Cliente',
        hintText: 'Número de orden o referencia',
        prefixIcon: Icon(
          Icons.receipt_long,
          color: Theme.of(context).primaryColor,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
      ),
      enabled: widget.enabled && !_isSubmitting,
      validator:
          (value) =>
              value == null || value.trim().isEmpty
                  ? 'La orden del cliente es obligatoria'
                  : null,
    );
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaIngreso,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _fechaIngreso) {
      setState(() => _fechaIngreso = picked);
      _onFieldChanged('FechaIngreso'); // ✅ Notificar cambio
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  Future<void> _seleccionarFechaFinalizacion() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaFinalizacion ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _fechaFinalizacion = picked;
        _fechaFinalizacionController.text = _formatearFecha(picked);
      });
      _onFieldChanged('FechaFinalizacionPicker'); // ✅ Notificar cambio
    }
  }

  /// ✅ NUEVO: Widget para selector de actividades
  Widget _buildSelectorActividades() {
    final store = PermissionStore.instance;
    final canView = store.can('servicios_actividades', 'ver');
    final canList = store.can('servicios_actividades', 'listar');

    if (!canView) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Usar color de branding configurado para el cono
              Icon(
                Icons.task_alt,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Actividad a Realizar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!canList)
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
                    'No tienes permisos para listar las actividades.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            )
          else
            ChangeNotifierProvider.value(
              value: widget.actividadesService!,
              child: ActividadSelectorWidget(
                servicio: widget.servicio!,
                onChanged: (actividadEstandar) {
                  // Actualizar estado local
                  setState(() {
                    _actividadSeleccionadaId = actividadEstandar?.id;
                  });

                  if (actividadEstandar != null &&
                      _equipoSeleccionado != null) {
                    _validarInspeccionActiva(
                      _equipoSeleccionado!.id,
                      actividadEstandar.id,
                    );
                  }
                  _onFieldChanged(); // ✅ Notificar cambio
                  widget.onActividadChanged?.call(actividadEstandar?.id);
                },
                enabled: widget.enabled && !_isSubmitting,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ordenClienteController.dispose();
    _oServicioController.dispose();
    _fechaFinalizacionController.dispose();
    super.dispose();
  }
}
