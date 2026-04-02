/// ============================================================================
/// ARCHIVO: servicio_edit_page.dart
///
/// PROPéSITO: Página para editar servicios existentes que:
/// - Carga datos del servicio a modificar
/// - Permite cambiar estados del servicio
/// - Gestiona campos adicionales por estado
/// - Maneja fechas de finalizacié³n
/// - Controla el campo de repuestos
/// - ? NUEVO: Valida campos adicionales obligatorios antes de cambios
///
/// USO: Se accede desde el boté³n editar (??) en la tabla de servicios
/// FUNCIéN: Formulario de edicié³n con funcionalidades adicionales como cambio de estado y campos dinámicos.
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Importar el formulario y servicios
import 'servicio_form.dart';
import '../models/servicio_model.dart';
import '../models/estado_model.dart';
import '../services/servicios_api_service.dart';
import '../services/fotos_service.dart';
import 'widgets/campos_adicionales.dart';
import 'widgets/fotos_servicio_widget.dart';
import '../workflow/estado_workflow_models.dart'; // ? IMPORTANTE
import '../workflow/estado_workflow_service.dart'; // ? NUEVO
import 'package:infoapp/core/enums/modulo_enum.dart'; // ? NUEVO
import '../services/actividades_service.dart';
// Imports para repuestos
import '../models/servicio_repuesto_model.dart';
import '../services/servicio_repuestos_api_service.dart';
import '../widgets/inventory_selection_modal.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import '../services/servicios_sync_queue.dart';
import 'package:infoapp/core/utils/servicios_cache.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/seccion_operaciones.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

/// Página especé­fica para editar servicios existentes
class ServicioEditPage extends StatefulWidget {
  final ServicioModel servicio;

  const ServicioEditPage({super.key, required this.servicio});

  @override
  State<ServicioEditPage> createState() => _ServicioEditPageState();
}

class _ServicioEditPageState extends State<ServicioEditPage> {
  // Key para acceder al estado del formulario y disparar el guardado
  final GlobalKey<ServicioFormState> _formKey = GlobalKey<ServicioFormState>();

  bool _canEditClosedOps = false;

  // --- Mover widgets auxiliares antes de build para evitar errores de referencia ---
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.primaryColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      widget.servicio.estaAnulado
                          ? Colors.red.withValues(alpha: 0.08)
                          : context.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.servicio.estaAnulado
                      ? PhosphorIcons.prohibit()
                      : PhosphorIcons.pencilSimple(),
                  color:
                      widget.servicio.estaAnulado
                          ? Colors.red
                          : context.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Editar Servicio #${widget.servicio.oServicio ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                widget.servicio.estaAnulado
                                    ? Colors.red
                                    : context.primaryColor,
                          ),
                        ),
                        if (widget.servicio.estaAnulado) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ANULADO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.servicio.estaAnulado
                          ? 'Este servicio ha sido anulado y no se puede modificar.'
                          : (_puedeAnular &&
                              PermissionStore.instance.can(
                                'servicios',
                                'eliminar',
                              ))
                          ? 'Modifica la informacié³n del servicio o anéºlalo si es necesario.'
                          : 'Modifica la informacié³n del servicio. Los cambios se guardarán al presionar "Actualizar".',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.servicio.estaAnulado && widget.servicio.razon != null) ...[
            const SizedBox(height: 16),
            _buildRazonAnulacion(),
          ],

          if (widget.servicio.estadoNombre != null) ...[
            const SizedBox(height: 16),
            _buildEstadoActual(),
          ],
        ],
      ),
    );
  }

  Widget _buildRazonAnulacion() {
    return Container(
      width: double.infinity,
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
              Icon(PhosphorIcons.info(), color: Colors.red.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                'Razé³n de Anulacié³n:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.servicio.razon!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// ? NUEVO: Banner de persistencia inteligente y workflow
  Widget _buildWorkflowBanner() {
    if (!_hasChanges) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.info(), color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cambios Pendientes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const Text(
                      'Debes presionar "Guardar" para que los cambios sean oficiales y se disparen las transiciones del workflow.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed:
                    _isUpdating || !_baseInitDone
                        ? null
                        : () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            _actualizarServicio(
                              _formKey.currentState!.servicioActual,
                            );
                          }
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('GUARDAR AHORA'),
              ),
            ],
          ),

          // ? NUEVO: Indicador de conexié³n
          FutureBuilder<bool>(
            future: ConnectivityService.instance.checkNow(),
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? true;
              if (!isOnline && !kIsWeb) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.cloudSlash(),
                        color: Colors.orange.shade800,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Modo Offline: Los cambios se guardarán localmente.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoActual() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _parseColor(widget.servicio.estadoColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _parseColor(
            widget.servicio.estadoColor,
          ).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _parseColor(widget.servicio.estadoColor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Estado Actual: ',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              Expanded(
                child: Text(
                  widget.servicio.estadoNombre!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _parseColor(widget.servicio.estadoColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (widget.servicio.estaAnulado) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ANULADO',
                style: TextStyle(
                  fontSize: 12, // Slightly larger on mobile focus
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ] else if (!widget.servicio.estaAnulado) ...[
            SizedBox(height: isMobile ? 12 : 0),
            // En mé³vil, boté³n full width. En desktop, boté³n normal alineado a la derecha
            isMobile
                ? Column(
                  children:
                      _accionesDisponibles.map((t) {
                        String label = t.nombre ?? 'Avanzar';
                        if (label.trim().isEmpty ||
                            label.trim().toLowerCase() == 'transición') {
                          label = t.to;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_isUpdating || _isAnulling)
                                      ? null
                                      : () => _formKey.currentState
                                          ?.avanzarEstado(t),
                              icon: Icon(_getIconForTrigger(t.triggerCode)),
                              label: Text(label),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children:
                      _accionesDisponibles.map((t) {
                        String label = t.nombre ?? 'Avanzar';
                        if (label.trim().isEmpty ||
                            label.trim().toLowerCase() == 'transición') {
                          label = t.to;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ElevatedButton.icon(
                            onPressed:
                                (_isUpdating || _isAnulling)
                                    ? null
                                    : () =>
                                        _formKey.currentState?.avanzarEstado(t),
                            icon: Icon(_getIconForTrigger(t.triggerCode)),
                            label: Text(label),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForTrigger(String? trigger) {
    switch (trigger) {
      case 'FIRMA_CLIENTE':
        return PhosphorIcons.penNib();
      case 'FOTO_SUBIDA':
        return PhosphorIcons.camera();
      default:
        return PhosphorIcons.arrowRight();
    }
  }

  bool _isUpdating = false;
  bool _hasChanges = false;
  bool _isAnulling = false;
  List<EstadoModel> _estados = [];
  bool _isLoadingEstados = true;

  // ? NUEVO: Helpers para Workflow Gating
  bool _isTriggerAvailable(String triggerCode) {
    return _accionesDisponibles.any(
      (t) => t.triggerCode?.toUpperCase() == triggerCode.toUpperCase(),
    );
  }

  bool _isTriggerConfigured(String triggerCode) {
    // Si no tenemos configuraciones cargadas, asumimos que no hay disparadores (Fallback)
    final config = EstadoWorkflowService().getConfig(
      modulo: ModuloEnum.servicios,
    );
    if (config == null || config.transiciones.isEmpty) return false;
    return config.transiciones.any(
      (t) => t.triggerCode?.toUpperCase() == triggerCode.toUpperCase(),
    );
  }

  // Variables para gestié³n de repuestos
  List<ServicioRepuestoModel> _repuestosAsignados = [];
  bool _isLoadingRepuestos = false;

  // Variables para gestié³n de staff

  // Variable para el servicio editado
  late ServicioModel _servicioEditado;

  // ? NUEVO: Referencia para validar campos adicionales
  final GlobalKey<CamposAdicionalesServiciosState> _camposAdicionalesKey =
      GlobalKey<CamposAdicionalesServiciosState>();

  // ? NUEVO: Variables para gestié³n de actividades
  late ActividadesService _actividadesService;
  int? _actividadSeleccionadaId;
  // Control de carga homogé©nea del formulario
  bool _isInitializingForm = true;
  // ? NUEVO: Seé±ales de preparacié³n interna del formulario
  bool _baseInitDone = false;

  // ? NUEVO: Contador de fotos
  int _cantidadFotos = 0;

  // ? NUEVO: Flag para ignorar cambios durante inicializacié³n completa
  bool _formFullyInitialized = false;

  // ? NUEVO: Lista de transiciones disponibles notificadas por el form
  List<WorkflowTransicionDef> _accionesDisponibles = [];

  @override
  void initState() {
    super.initState();
    _actividadesService = ActividadesService(); // ? NUEVO
    _actividadSeleccionadaId = widget.servicio.actividadId; // ? NUEVO
    _servicioEditado = widget.servicio;
    _loadUserPermissions();
    // Reiniciar seé±ales de preparacié³n
    _baseInitDone = false;
    _formFullyInitialized =
        false; // ? CRéTICO: Resetear flag de inicializacié³n
    _hasChanges = false; // ? CRéTICO: Resetear tracking de cambios
    // Cargar todo en paralelo y mostrar la UI solo cuando termine
    _inicializarFormularioHomogeneo();
  }

  /// Inicializa la edicié³n cargando todo en paralelo y mostrando el formulario
  /// éºnicamente cuando todos los datos iniciales hayan sido cargados.
  Future<void> _inicializarFormularioHomogeneo() async {
    setState(() => _isInitializingForm = true);

    final tareas = <Future<void>>[];
    // ? NUEVO: Forzar recarga de transiciones desde el backend al entrar a editar
    // Esto asegura que si el usuario cambié³ nombres de estados o triggers en el panel, la App los vea.
    tareas.add(EstadoWorkflowService().reload(modulo: ModuloEnum.servicios));

    tareas.add(_cargarEstados());
    // Estas dependen del ID del servicio; si no hay ID, sus mé©todos retornan temprano
    // tareas.add(_cargarFotosServicio()); // Eliminado: ahora gestionado por FotosServicioWidget
    tareas.add(_cargarRepuestosAsignados());
    tareas.add(_actualizarContadorFotos()); // ? NUEVO: Cargar contador inicial

    // ? OPTIMIZACIéN: Pre-cargar campos adicionales en paralelo
    if (_servicioEditado.estadoId != null) {
      tareas.add(_precargarCamposAdicionales());
    }

    try {
      await Future.wait(tareas);
    } catch (_) {
      // Evitar que una falla impida el render; los mé©todos internos ya notifican errores
    } finally {
      if (mounted) {
        setState(() {
          _baseInitDone = true;
        });
        _tryReleaseGlobalLoader();

        // ? CRéTICO: Dar tiempo para que el formulario termine de construirse
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _formFullyInitialized = true);
          }
        });
      }
    }
  }

  Future<void> _loadUserPermissions() async {
    final canEdit = await AuthService.canEditClosedOps();
    if (mounted) {
      setState(() {
        _canEditClosedOps = canEdit;
      });
    }
  }

  /// ? NUEVO: Pre-cargar campos adicionales para que esté©n listos cuando el widget los pida
  Future<void> _precargarCamposAdicionales() async {
    if (_servicioEditado.estadoId == null) return;
    try {
      // Esto cargará los datos en el caché© del servicio API
      // Cuando el widget CamposAdicionalesServicios los pida, ya estarán en memoria
      await ServiciosApiService.obtenerCamposPorEstado(
        estadoId: _servicioEditado.estadoId!,
        modulo: 'Servicios',
      );
    } catch (_) {}
  }

  // ? NUEVO: Liberar el loader global solo cuando todo esté© listo
  void _tryReleaseGlobalLoader() {
    if (!mounted) return;
    final listo = _baseInitDone && !_isLoadingEstados;
    if (listo && _isInitializingForm) {
      setState(() => _isInitializingForm = false);
    }
  }

  // ========== FUNCIONES ORIGINALES CON VALIDACIéN MEJORADA ==========

  /// ? NUEVO: Actualizar contador de fotos
  Future<void> _actualizarContadorFotos() async {
    if (widget.servicio.id == null) return;
    try {
      final contadores = await FotosService.contarFotosPorTipo(
        widget.servicio.id!,
      );
      if (mounted) {
        setState(() {
          _cantidadFotos = contadores['total'] ?? 0;
        });
      }
    } catch (_) {}
  }

  /// Mostrar modal de fotos
  void _mostrarModalFotos({bool forceReadOnly = false}) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              child: FotosServicioWidget(
                servicioId: widget.servicio.id ?? 0,
                numeroServicio: widget.servicio.oServicio?.toString() ?? '',
                // ? MODIFICADO: Bloqueo explé­cito o por estado
                enabled:
                    !forceReadOnly &&
                    !widget.servicio.estaAnulado &&
                    !_isAnulling &&
                    !_esServicioBloqueado,
                onFotosChanged: () async {
                  await _actualizarContadorFotos();

                  // ? NUEVO: Refrescar datos del servicio por si hubo cambio de estado automático
                  await _refrescarDatosServicio();

                  // ? NUEVO: Marcar cambios al subir fotos para forzar guardado inteligente
                  if (mounted && !_hasChanges) {
                    setState(() => _hasChanges = true);
                  }
                },
              ),
            ),
          ),
    );
  }

  /// ? NUEVO: Refrescar datos del servicio desde el servidor
  Future<void> _refrescarDatosServicio() async {
    if (widget.servicio.id == null) return;

    try {
      final response = await ServiciosApiService.obtenerServicio(
        widget.servicio.id!,
      );
      if (response.success && response.data != null) {
        if (mounted) {
          setState(() {
            _servicioEditado = response.data!;
          });

          if (response.data!.estadoId != widget.servicio.estadoId) {
            debugPrint(
              '?? Cambio de estado detectado (${widget.servicio.estadoNombre} -> ${response.data!.estadoNombre}).',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error refrescando servicio: $e');
    }
  }

  Future<void> _cargarEstados() async {
    try {
      final estados = await ServiciosApiService.listarEstados();
      if (context.mounted) {
        setState(() {
          _estados = estados;
          _isLoadingEstados = false;
        });
      }
    } catch (e) {
      //       print('? Error cargando estados: $e');
      if (mounted) {
        setState(() {
          _isLoadingEstados = false;
        });
      }
    }
  }

  bool get _puedeAnular {
    if (_isLoadingEstados || _estados.isEmpty || widget.servicio.estaAnulado) {
      return false;
    }
    final primerEstado = _estados.first;
    return widget.servicio.estadoId == primerEstado.id;
  }

  // ✅ Getter centralizado para saber si el servicio está bloqueado (Solo lectura)
  bool get _esServicioBloqueado {
    if (widget.servicio.estaAnulado) return true;

    // 1. ESTADO TERMINAL ABSOLUTO (Legalizado/Cancelado):
    // Se permite el bypass si el usuario tiene permiso especial de edición de operaciones cerradas.
    if (widget.servicio.esTerminal(_estados)) {
      return !_canEditClosedOps;
    }

    // 2. ESTADO FINAL INTERMEDIO (Finalizado/Cerrado): Bloqueo condicional al permiso.
    final esFinalIntermedio = widget.servicio.esFinal(_estados);
    if (esFinalIntermedio && !_canEditClosedOps) return true;

    return false;
  }

  /// ? MéTODO ACTUALIZADO: Validar campos adicionales antes de actualizar
  Future<void> _actualizarServicio(ServicioModel servicioEditado) async {
    if (_isUpdating) return;

    // ? NUEVA VALIDACIéN: Verificar campos obligatorios antes de actualizar
    final puedeProceeder = await _validarCamposAdicionales(
      accion: 'actualizar servicio',
    );
    if (!puedeProceeder) {
      return; // No proceder si la validacié³n fallé³
    }

    setState(() => _isUpdating = true);

    try {
      // ? NUEVO: Agregar actividad seleccionada al servicio
      final servicioConActividad = servicioEditado.copyWith(
        actividadId: _actividadSeleccionadaId,
      );

      //       print('?? Actualizando servicio: ${servicioConActividad.toString()}');
      // Verificar conectividad actual
      final isOnline = await ConnectivityService.instance.checkNow();

      if (!isOnline) {
        if (kIsWeb) {
          _mostrarError('En la web no se permite trabajar sin conexié³n.');
          return;
        }
        // Encolar actualizacié³n para sincronizacié³n posterior
        await ServiciosSyncQueue.enqueueUpdate(servicioConActividad);

        // Reflejar cambios en el caché© local inmediatamente
        try {
          final lista = await ServiciosCache.loadList();
          if (lista != null) {
            int index = -1;
            if (servicioConActividad.id != null) {
              index = lista.indexWhere((s) => s.id == servicioConActividad.id);
            } else if (servicioConActividad.oServicio != null) {
              index = lista.indexWhere(
                (s) => s.oServicio == servicioConActividad.oServicio,
              );
            }
            if (index >= 0) {
              lista[index] = servicioConActividad;
              await ServiciosCache.saveList(lista);
            }
          }
        } catch (_) {}
        _mostrarExito(
          'Sin conexié³n. Los cambios se guardaron localmente y se sincronizarán al reconectar.',
        );
        setState(() => _hasChanges = false);
        await Future.delayed(const Duration(milliseconds: 700));
        if (context.mounted) {
          Navigator.pop(context, servicioEditado);
        }
        return;
      }

      final resultado = await ServiciosApiService.actualizarServicio(
        servicioConActividad,
      );

      if (resultado.isSuccess) {
        _mostrarExito(
          resultado.message ??
              'Servicio #${resultado.data?.oServicio} actualizado exitosamente',
        );

        setState(() => _hasChanges = false);
        await Future.delayed(const Duration(seconds: 1));

        if (context.mounted) {
          Navigator.pop(context, resultado.data ?? servicioEditado);
        }
      } else {
        _mostrarError(
          resultado.error ?? 'Error desconocido al actualizar servicio',
        );
      }
    } catch (e) {
      //       print('? Error actualizando servicio: $e');
      _mostrarError('Error de conexié³n: $e');
    } finally {
      if (context.mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _mostrarModalAnulacion() {
    // ? NUEVO: Verificar si hay repuestos asignados
    if (_repuestosAsignados.isNotEmpty) {
      _mostrarDialogoBloqueoPorRepuestos();
      return;
    }

    final razonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
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
                          Expanded(
                            child: Text(
                              '?? Esta accié³n NO se puede revertir. Una vez anulado el servicio, no podrá volver a su estado anterior.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Razé³n de anulacié³n:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: razonController,
                      inputFormatters: [UpperCaseTextFormatter()],
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe el motivo de la anulacié³n...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La razé³n es obligatoria';
                        }
                        if (value.trim().length < 40) {
                          return 'La razé³n debe tener al menos 40 caracteres';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    ValueListenableBuilder(
                      valueListenable: razonController,
                      builder: (context, value, child) {
                        final length = value.text.length;
                        final color =
                            length >= 40
                                ? context.successColor
                                : Theme.of(context).colorScheme.error;
                        return Text(
                          '$length/40 caracteres mé­nimos',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500,
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
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    await _anularServicio(razonController.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Anular Servicio'),
              ),
            ],
          ),
    );
  }

  /// ? NUEVO: Diálogo cuando hay repuestos asignados
  void _mostrarDialogoBloqueoPorRepuestos() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(PhosphorIcons.package(), color: Colors.orange.shade800),
                const SizedBox(width: 8),
                const Text('Repuestos Asignados'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'No es posible anular el servicio porque tiene ${_repuestosAsignados.length} repuestos asignados.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Para anular el servicio, primero debes eliminar los repuestos para devolverlos al inventario.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _eliminarRepuestosYContinuar();
                },
                icon: Icon(PhosphorIcons.trashSimple()),
                label: const Text('Eliminar Repuestos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _eliminarRepuestosYContinuar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Eliminar todos los repuestos?'),
            content: const Text(
              'Esta accié³n eliminará todos los repuestos asignados a este servicio y los devolverá al inventario.\n\n¿Estás seguro?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sé­, Eliminar Todo'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    _mostrarCargando('Devolviendo repuestos al inventario...');

    try {
      final resultado =
          await ServicioRepuestosApiService.eliminarTodosRepuestosServicio(
            servicioId: widget.servicio.id!,
            razon: 'Anulacié³n de servicio prevent',
          );

      _ocultarCargando();

      if (resultado.isSuccess) {
        _mostrarExito('Repuestos eliminados exitosamente');
        // Recargar repuestos para actualizar la UI y la variable local
        await _cargarRepuestosAsignados(forceRefresh: true);
        // Ahora sé­, mostrar el diálogo de anulacié³n
        if (mounted) {
          // Pequeé±o delay para UX
          await Future.delayed(const Duration(milliseconds: 300));
          _mostrarModalAnulacion();
        }
      } else {
        _mostrarError(resultado.message ?? 'Error eliminando repuestos');
      }
    } catch (e) {
      _ocultarCargando();
      _mostrarError('Error de conexié³n: $e');
    }
  }

  /// ? MéTODO ACTUALIZADO: Validar campos antes de anular
  Future<void> _anularServicio(String razon) async {
    if (_isAnulling || widget.servicio.id == null) return;

    setState(() => _isAnulling = true);

    try {
      //       print('?? Anulando servicio ID: ${widget.servicio.id} con razé³n: $razon');

      // NUEVO: Obtener estados para encontrar el estado final
      final estados = await ServiciosApiService.listarEstados();
      if (estados.isEmpty) {
        throw Exception('No se pudieron cargar los estados');
      }

      // Buscar estado final (éºltimo estado o uno especé­fico para anulados)
      final estadoFinal = estados.last; // O busca uno especé­fico por nombre

      final resultado = await ServiciosApiService.anularServicio(
        servicioId: widget.servicio.id!,
        estadoFinalId: estadoFinal.id, // AGREGADO: Pasar estado final
        razon: razon,
      );

      if (resultado.isSuccess) {
        _mostrarExito(
          resultado.message ??
              'Servicio #${widget.servicio.oServicio} anulado exitosamente',
        );

        setState(() => _hasChanges = false);
        await Future.delayed(const Duration(seconds: 2));

        final servicioAnulado = widget.servicio.copyWith(
          anularServicio: true,
          razon: razon,
          estadoId: estadoFinal.id,
          estadoNombre: estadoFinal.nombre,
          estadoColor: estadoFinal.color,
          fechaFinalizacion: DateTime.now().toIso8601String(),
        );

        if (context.mounted) {
          Navigator.pop(context, servicioAnulado);
        }
      } else {
        _mostrarError(
          resultado.error ?? 'Error desconocido al anular servicio',
        );
      }
    } catch (e) {
      //       print('? Error anulando servicio: $e');
      _mostrarError('Error de conexié³n: $e');
    } finally {
      if (context.mounted) {
        setState(() => _isAnulling = false);
      }
    }
  }

  /// ? NUEVOS MéTODOS: Validacié³n de campos adicionales
  Future<bool> _validarCamposAdicionales({String accion = 'proceder'}) async {
    // Verificar si existe el widget de campos adicionales
    final camposWidget = _camposAdicionalesKey.currentState;

    if (camposWidget == null) {
      // No hay widget de campos, proceder normalmente
      return true;
    }

    //     print('?? Validando campos adicionales antes de $accion...');

    // Validar campos obligatorios
    if (!camposWidget.puedeCambiarEstado()) {
      //       print('? Validacié³n fallida: hay campos obligatorios sin completar');
      // La validacié³n ya muestra el diálogo de error
      return false;
    }

    // Si hay campos adicionales, guardarlos antes del cambio
    try {
      //       print('?? Guardando campos adicionales antes de $accion...');

      _mostrarCargando('Guardando campos adicionales...');
      final guardadoExitoso = await camposWidget.guardarCamposAdicionales();
      _ocultarCargando();

      if (!guardadoExitoso) {
        _mostrarError(
          'Error guardando campos adicionales. Intente nuevamente.',
        );
        return false;
      }

      //       print('? Campos adicionales guardados exitosamente');
      return true;
    } catch (e) {
      _ocultarCargando();
      //       print('? Error guardando campos adicionales: $e');
      _mostrarError('Error inesperado guardando campos: $e');
      return false;
    }
  }

  /// ? NUEVO: Mostrar diálogo de carga
  void _mostrarCargando(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Expanded(child: Text(mensaje)),
                ],
              ),
            ),
          ),
    );
  }

  /// ? NUEVO: Ocultar diálogo de carga
  void _ocultarCargando() {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _mostrarError(String mensaje) {
    if (context.mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(PhosphorIcons.warningCircle(), color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(mensaje, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        // Ignorar errores si el widget está desactivado
        // print('Error mostrando snackbar: $e');
      }
    }
  }

  void _mostrarExito(String mensaje) {
    if (context.mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(PhosphorIcons.checkCircle(), color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(mensaje, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
            backgroundColor: context.successColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (_) {}
    }
  }

  void _cancelarEdicion() {
    if (_hasChanges && !_isUpdating && !_isAnulling) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(PhosphorIcons.warning(), color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Cambios sin Guardar'),
                ],
              ),
              content: const Text(
                '¿Estás seguro de que quieres salir? '
                'Hay cambios sin guardar que se perderán.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continuar Editando'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  child: const Text('Sé­, Salir'),
                ),
              ],
            ),
      );
    } else if (!_isUpdating && !_isAnulling) {
      Navigator.pop(context);
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
  // =====================================
  //    MéTODOS PARA GESTIéN DE REPUESTOS
  // =====================================

  Future<void> _cargarRepuestosAsignados({bool forceRefresh = false}) async {
    if (widget.servicio.id == null) return;

    setState(() {
      _isLoadingRepuestos = true;
    });

    try {
      final response =
          await ServicioRepuestosApiService.listarRepuestosDeServicio(
            servicioId: widget.servicio.id!,
            incluirDetallesItem: true,
            forceRefresh: forceRefresh,
          );

      if (response.success && response.data != null) {
        setState(() {
          _repuestosAsignados = response.data!.repuestos;
          _servicioEditado = _servicioEditado.copyWith(
            suministraronRepuestos: _repuestosAsignados.isNotEmpty,
          );
        });
        // LOGS DE DEPURACIéN
        //         print('? Repuestos cargados: ${_repuestosAsignados.length}');
        //         print('?? Datos de repuestos:');
        //         print('?? Estado suministraronRepuestos: \\${_servicioEditado.suministraronRepuestos}');
      }
    } catch (e) {
      //       print('? Error cargando repuestos: $e');
    } finally {
      if (context.mounted) {
        setState(() {
          _isLoadingRepuestos = false;
        });
      }
    }
  }

  void _mostrarModalSeleccionRepuestos() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => InventorySelectionModal(
            servicioId: widget.servicio.id!,
            numeroOrden: widget.servicio.oServicio?.toString(),
            repuestosYaAsignados: _repuestosAsignados,
            enabled: !_esServicioBloqueado && !widget.servicio.estaAnulado,
            onRepuestosSeleccionados: (list) {
              setState(() {
                _repuestosAsignados = list;
                _servicioEditado = _servicioEditado.copyWith(
                  suministraronRepuestos: list.isNotEmpty,
                );
              });
            },
            // AGREGAR ESTA LéNEA:
            onRepuestosActualizados: () async {
              await _cargarRepuestosAsignados(forceRefresh: true);

              // ? NUEVO: Refrescar datos del servicio por si hubo cambio de estado automático
              await _refrescarDatosServicio();

              // ? NUEVO: Marcar cambios al actualizar repuestos
              if (mounted && !_hasChanges) {
                setState(() => _hasChanges = true);
              }
            },
          ),
    );

    // AGREGAR ESTAS LéNEAS:
    // Recargar repuestos independientemente del resultado
    await _cargarRepuestosAsignados();

    if (result == true) {
      setState(() {
        _servicioEditado = _servicioEditado.copyWith(
          suministraronRepuestos: true,
        );
      });
    }
  }

  Future<void> _eliminarRepuesto(ServicioRepuestoModel repuesto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Eliminar Repuesto'),
            content: Text(
              '¿Está seguro de eliminar "${repuesto.itemNombre}" del servicio?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      try {
        final response =
            await ServicioRepuestosApiService.eliminarRepuestoDeServicio(
              servicioRepuestoId: repuesto.id!,
            );

        if (response.success) {
          _mostrarExito('Repuesto eliminado exitosamente');
          await _cargarRepuestosAsignados(forceRefresh: true);
          // ? NUEVO: Marcar cambios al eliminar repuesto
          if (mounted && !_hasChanges) {
            setState(() => _hasChanges = true);
          }
        } else {
          throw Exception(response.message);
        }
      } catch (e) {
        _mostrarError('Error: $e');
      }
    }
  }

  Widget _buildSeccionRepuestos() {
    final store = PermissionStore.instance;
    // 1. VER: Puerta de entrada a la seccié³n
    final canView = store.can('servicios_repuestos', 'ver');
    // 2. LISTAR: Puerta de entrada la data
    final canList = store.can('servicios_repuestos', 'listar');

    final canGestionarRepuestos = store.can(
      'servicios_repuestos',
      'actualizar',
    );
    if (!canView) return const SizedBox.shrink();

    // Si no puede listar, mostrar bloqueo visual (pero la tarjeta existe porque puede ver)
    if (!canList) {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(PhosphorIcons.wrench(), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Repuestos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Divider(),
              SizedBox(height: 16),
              Icon(
                PhosphorIcons.lockKey(),
                size: 48,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: 16),
              Text(
                'No tienes permisos para ver la lista de repuestos.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ? BANNER DE BLOQUEO (si aplica)
            if (_servicioEditado.bloqueoRepuestos == true)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.lock(), color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Repuestos Bloqueados',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          Text(
                            'El servicio ya fue firmado. No se pueden modificar repuestos.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ? BOTéN DESBLOQUEAR (Solo si tiene permiso)
                    if (store.can('servicios_repuestos', 'desbloquear'))
                      TextButton.icon(
                        onPressed: _mostrarDialogoDesbloqueo,
                        icon: Icon(PhosphorIcons.lockOpen(), size: 18),
                        label: const Text('Desbloquear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange.shade900,
                        ),
                      ),
                  ],
                ),
              ),

            Row(
              children: [
                Checkbox(
                  value: _servicioEditado.suministraronRepuestos == true,
                  onChanged:
                      canGestionarRepuestos &&
                              (_servicioEditado.bloqueoRepuestos != true) &&
                              !widget.servicio.estaAnulado &&
                              !_esServicioBloqueado && // ? Bloqueo estado final
                              // ? NUEVO: Gating por Workflow
                              (_isTriggerAvailable('OS_REPUESTOS') ||
                                  !_isTriggerConfigured('OS_REPUESTOS'))
                          ? (checked) {
                            setState(() {
                              _servicioEditado = _servicioEditado.copyWith(
                                suministraronRepuestos: checked ?? false,
                              );
                            });
                          }
                          : null,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Repuestos Suministrados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ? CORRECCIéN VISIBILIDAD: Mostrar siempre si hay repuestos asignados, incluso si el checkbox está off
            if (_servicioEditado.suministraronRepuestos == true ||
                _repuestosAsignados.isNotEmpty) ...[
              Divider(),
              if (_isLoadingRepuestos)
                Center(child: CircularProgressIndicator())
              else if (_repuestosAsignados.isEmpty)
                Container(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text('No hay repuestos asignados'),
                      SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          // ? validacié³n adicional de bloqueo
                          final estaBloqueado =
                              _servicioEditado.bloqueoRepuestos == true;

                          // ? NUEVO: Gating por Workflow para boté³n Agregar
                          final triggerDisponible = _isTriggerAvailable(
                            'OS_REPUESTOS',
                          );
                          final triggerConfigurado = _isTriggerConfigured(
                            'OS_REPUESTOS',
                          );
                          final puedeAgregarActualmente =
                              triggerDisponible || !triggerConfigurado;

                          return canGestionarRepuestos &&
                                  !estaBloqueado &&
                                  !widget.servicio.estaAnulado &&
                                  !_esServicioBloqueado && // ? Bloqueo estado final
                                  puedeAgregarActualmente
                              ? ElevatedButton.icon(
                                onPressed: _mostrarModalSeleccionRepuestos,
                                icon: Icon(PhosphorIcons.plus()),
                                label: Text('Agregar Repuestos'),
                              )
                              : !puedeAgregarActualmente
                              ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'El workflow no permite agregar repuestos en este estado.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                              : SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                )
              else
                _buildTablaRepuestos(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTablaRepuestos() {
    final store = PermissionStore.instance;
    final canGestionarRepuestos = store.can(
      'servicios_repuestos',
      'actualizar',
    );
    double costoTotal = _repuestosAsignados.fold(
      0,
      (sum, item) => sum + item.costoTotal,
    );

    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final isMobile = MediaQuery.of(context).size.width < 600;

    // --- VISTA MéVIL (TARJETAS) ---
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera Mé³vil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Repuestos (${_repuestosAsignados.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (canGestionarRepuestos &&
                  _servicioEditado.bloqueoRepuestos != true &&
                  !widget.servicio.estaAnulado &&
                  !_esServicioBloqueado) // ? Bloqueo estado final
                ElevatedButton.icon(
                  onPressed: _mostrarModalSeleccionRepuestos,
                  icon: Icon(PhosphorIcons.plus(), size: 18),
                  label: const Text('Agregar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Lista de Tarjetas
          ..._repuestosAsignados.map((repuesto) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Fila 1: Nombre y Boté³n Eliminar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                repuesto.itemNombre ?? 'N/A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'SKU: ${repuesto.itemSku ?? 'N/A'}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canGestionarRepuestos &&
                            _servicioEditado.bloqueoRepuestos != true &&
                            !widget.servicio.estaAnulado &&
                            !_esServicioBloqueado) // ? Bloqueo estado final
                          IconButton(
                            onPressed: () => _eliminarRepuesto(repuesto),
                            icon: Icon(
                              PhosphorIcons.trashSimple(),
                              color: Theme.of(context).colorScheme.error,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.1),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Fila 2: Detalles Numé©ricos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoCellMobile(
                          'Cant.',
                          repuesto.cantidad.toStringAsFixed(2),
                        ),
                        _infoCellMobile(
                          'Precio',
                          currencyFormat.format(repuesto.costoUnitario),
                        ),
                        _infoCellMobile(
                          'Total',
                          currencyFormat.format(repuesto.costoTotal),
                          isBold: true,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          // Footer Total Mé³vil
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL GLOBAL:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  currencyFormat.format(costoTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // --- VISTA ESCRITORIO (TABLA) ---
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Repuestos Asignados (${_repuestosAsignados.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (canGestionarRepuestos &&
                _servicioEditado.bloqueoRepuestos != true &&
                !widget.servicio.estaAnulado &&
                !_esServicioBloqueado) // ? Bloqueo estado final
              ElevatedButton.icon(
                onPressed: _mostrarModalSeleccionRepuestos,
                icon: Icon(PhosphorIcons.plus(), size: 20),
                label: const Text('Agregar'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Repuesto',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Cant.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Precio',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              ..._repuestosAsignados.map(
                (repuesto) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repuesto.itemNombre ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'SKU: ${repuesto.itemSku ?? 'N/A'}',
                              style: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(repuesto.cantidad.toStringAsFixed(2)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          currencyFormat.format(repuesto.costoUnitario),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          currencyFormat.format(repuesto.costoTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (canGestionarRepuestos &&
                          _servicioEditado.bloqueoRepuestos != true &&
                          !widget.servicio.estaAnulado)
                        IconButton(
                          onPressed: () => _eliminarRepuesto(repuesto),
                          icon: Icon(
                            PhosphorIcons.trashSimple(),
                            color: Theme.of(context).colorScheme.error,
                          ),
                          iconSize: 20,
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currencyFormat.format(costoTotal),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCellMobile(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  // ? NUEVO: Diálogo para desbloquear repuestos
  void _mostrarDialogoDesbloqueo() {
    final motivoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(PhosphorIcons.lockOpen(), color: Colors.orange.shade800),
                const SizedBox(width: 8),
                const Text('Desbloquear Repuestos'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '?? Este servicio ya fue firmado. Para modificar repuestos, debes autorizar el desbloqueo justificando la razé³n.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: motivoController,
                      inputFormatters: [UpperCaseTextFormatter()],
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Motivo del desbloqueo',
                        hintText:
                            'Ej: Error en cantidad, repuesto defectuoso...',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 10) {
                          return 'El motivo debe tener al menos 10 caracteres';
                        }
                        return null;
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
              ElevatedButton.icon(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    await _desbloquearRepuestos(motivoController.text.trim());
                  }
                },
                icon: Icon(PhosphorIcons.check()),
                label: const Text('Autorizar Desbloqueo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  // ? NUEVO: Lé³gica para llamar al API de desbloqueo
  Future<void> _desbloquearRepuestos(String motivo) async {
    if (widget.servicio.id == null) return;

    _mostrarCargando('Desbloqueando repuestos...');
    try {
      final resultado = await ServiciosApiService.desbloquearRepuestos(
        servicioId: widget.servicio.id!,
        motivo: motivo,
      );

      _ocultarCargando();

      if (resultado.isSuccess) {
        _mostrarExito('Repuestos desbloqueados exitosamente');
        setState(() {
          // Actualizar estado local para reflejar el desbloqueo inmediato
          _servicioEditado = _servicioEditado.copyWith(bloqueoRepuestos: false);
        });
        // Recargar datos para asegurar sincroné­a
        await _cargarRepuestosAsignados(forceRefresh: true);
      } else {
        _mostrarError(resultado.error ?? 'Error al desbloquear');
      }
    } catch (e) {
      _ocultarCargando();
      _mostrarError('Error: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final store = PermissionStore.instance;
    final canUpdate = store.can('servicios', 'actualizar');

    // 🛡ï¸  GUARDIA DE SEGURIDAD: Verificar permiso de edición
    if (!canUpdate) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Denegado')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.lockKey(), size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'No tienes permisos para editar servicios.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final canVerFotos = store.can(
      'servicios_fotos',
      'ver',
    ); // O 'fotos' segun tu esquema

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isUpdating && !_isAnulling) {
          _cancelarEdicion();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Editar Servicio #${widget.servicio.oServicio ?? 'N/A'}'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(PhosphorIcons.x()),
            onPressed: (_isUpdating || _isAnulling) ? null : _cancelarEdicion,
            tooltip: 'Cancelar',
          ),
          actions: [
            // Botones principales en el header
            if (!_isUpdating && !_isAnulling) ...[
              // Cancelar: Solo en Desktop (en mé³vil ya está la X a la izquierda/leading)
              if (!isMobile) ...[
                TextButton.icon(
                  onPressed: _cancelarEdicion,
                  icon: Icon(PhosphorIcons.prohibit(), color: Colors.white),
                  label: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              if (widget.servicio.estaAnulado ||
                  _esServicioBloqueado ||
                  !canUpdate)
                const SizedBox.shrink()
              else
                // Actualizar: Icono en mé³vil, Boté³n en Desktop
                isMobile
                    ? IconButton(
                      onPressed:
                          _isUpdating ||
                                  !_baseInitDone ||
                                  !_hasChanges || // ? Deshabilitar si no hay cambios
                                  (_camposAdicionalesKey
                                          .currentState
                                          ?.estaCargando ??
                                      false)
                              ? null
                              : () {
                                if (_formKey.currentState!.validate()) {
                                  _formKey.currentState!.save();
                                  _actualizarServicio(
                                    _formKey.currentState!.servicioActual,
                                  );
                                }
                              },
                      icon:
                          _isUpdating
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Icon(PhosphorIcons.floppyDisk()),
                      tooltip: 'Guardar',
                    )
                    : ElevatedButton.icon(
                      onPressed:
                          _isUpdating ||
                                  !_baseInitDone ||
                                  !_hasChanges || // ? Deshabilitar si no hay cambios
                                  (_camposAdicionalesKey
                                          .currentState
                                          ?.estaCargando ??
                                      false)
                              ? null
                              : () {
                                if (_formKey.currentState!.validate()) {
                                  _formKey.currentState!.save();
                                  _actualizarServicio(
                                    _formKey.currentState!.servicioActual,
                                  );
                                } else {
                                  final camposWidget =
                                      _camposAdicionalesKey.currentState;
                                  if (camposWidget != null &&
                                      !camposWidget.puedeCambiarEstado()) {
                                    // Error manejado
                                  }
                                }
                              },
                      icon:
                          _isUpdating
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Icon(PhosphorIcons.floppyDisk()),
                      label: Text(_isUpdating ? 'Guardando...' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _hasChanges
                                ? Colors
                                    .orange
                                    .shade800 // ? Destacar si hay cambios
                                : context.primaryColor,
                        foregroundColor: Colors.white,
                        elevation:
                            _hasChanges
                                ? 4
                                : 2, // ? Sombra más fuerte si hay cambios
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
              const SizedBox(width: 12),
            ],
            // Boté³n de fotos
            if (widget.servicio.id != null &&
                !widget.servicio.estaAnulado &&
                canVerFotos) ...[
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      onPressed:
                          ((_esServicioBloqueado ||
                                      widget.servicio.estaAnulado) &&
                                  _cantidadFotos == 0)
                              ? null
                              : () {
                                final isBloqueado =
                                    _esServicioBloqueado ||
                                    widget.servicio.estaAnulado;

                                // ? NUEVO: Gating por Workflow para Fotos
                                // Si el formulario aéºn no carga sus transiciones, permitimos por defecto (evita race conditions)
                                final triggerActivo =
                                    !_formFullyInitialized ||
                                    _isTriggerAvailable('FOTO_SUBIDA') ||
                                    !_isTriggerConfigured('FOTO_SUBIDA');

                                if (isBloqueado) {
                                  // ? MODO SOLO LECTURA: Si tiene fotos, permitir ver
                                  if (_cantidadFotos > 0) {
                                    _mostrarModalFotos(forceReadOnly: true);
                                  }
                                } else {
                                  // Estado ABIERTO
                                  if (triggerActivo) {
                                    // ? MODO EDICIéN
                                    _mostrarModalFotos(forceReadOnly: false);
                                  } else {
                                    // Trigger inactivo
                                    if (_cantidadFotos > 0) {
                                      // ? MODO SOLO LECTURA (Tiene fotos pero ya no puede subir más)
                                      _mostrarModalFotos(forceReadOnly: true);
                                    } else {
                                      _mostrarError(
                                        'El workflow no permite subir fotos en este estado.',
                                      );
                                    }
                                  }
                                }
                              },
                      icon: Icon(PhosphorIcons.images()),
                      tooltip: 'Gestionar Fotos',
                    ),
                    if (_cantidadFotos > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$_cantidadFotos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],

            if (_puedeAnular &&
                !_isAnulling &&
                !_isUpdating &&
                PermissionStore.instance.can('servicios', 'eliminar')) ...[
              IconButton(
                onPressed: _mostrarModalAnulacion,
                icon: Icon(PhosphorIcons.prohibit()),
                tooltip: 'Anular Servicio',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade600.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 8),
            ],

            if (_isUpdating || _isAnulling)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
            else if (_hasChanges)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white, // ? Destacar más el indicador
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sin guardar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.surface,
              ],
              stops: const [0.0, 0.3],
            ),
          ),
          child:
              (_isInitializingForm || _isLoadingEstados)
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cargando formulario...',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                  : SingleChildScrollView(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 600 ? 12 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWorkflowBanner(), // ? NUEVO: Banner de persistencia inteligente
                        _buildHeaderCard(),
                        const SizedBox(height: 24),

                        // ? CAMBIO PRINCIPAL: Pasar la key al ServicioForm
                        // Formulario de edicié³n
                        ServicioForm(
                          key: _formKey,
                          camposAdicionalesKey: _camposAdicionalesKey,
                          servicio:
                              _servicioEditado, // Usa el objeto refrescado
                          onSaved: _actualizarServicio,
                          onError: _mostrarError,
                          onInitialized: () {
                            _tryReleaseGlobalLoader();
                          },
                          onCamposAdicionalesLoaded: () {
                            _tryReleaseGlobalLoader();
                          },
                          isEditing: true,
                          enabled:
                              !_isUpdating &&
                              !_isAnulling &&
                              !widget.servicio.estaAnulado &&
                              !_esServicioBloqueado, // ? Bloqueo estado final
                          // ? NUEVO: Pasar datos de actividad
                          actividadesService: _actividadesService,
                          actividadSeleccionadaId: _actividadSeleccionadaId,
                          onActividadChanged: (actividadId) {
                            print(
                              '?? [ServicioEditPage] onActividadChanged called: $actividadId',
                            );
                            setState(() {
                              _actividadSeleccionadaId = actividadId;
                              _hasChanges = true;
                              print(
                                '   ? _hasChanges set to TRUE (actividad changed)',
                              );
                            });
                            //                     print('? Actividad seleccionada en edicié³n: $actividadId');
                          },
                          // ? NUEVO: Recibir transiciones disponibles del workflow
                          onTransitionsLoaded: (acciones) {
                            if (mounted) {
                              setState(() => _accionesDisponibles = acciones);
                            }
                          },
                          // ? NUEVO: Pasar validacié³n de repuestos
                          onValidateRepuestos: _validarRepuestos,
                          onChanged: () {
                            // ? CRéTICO: Retornar INMEDIATAMENTE si no está inicializado
                            if (!_formFullyInitialized) {
                              print(
                                '?? [ServicioEditPage] onChanged BLOCKED: form not initialized',
                              );
                              return;
                            }

                            print(
                              '?? [ServicioEditPage] onChanged: _hasChanges=$_hasChanges',
                            );
                            if (mounted && !_hasChanges) {
                              setState(() {
                                _hasChanges = true;
                                print('   ? _hasChanges set to TRUE');
                              });
                            } else {
                              print('   ?? Skipped: already has changes');
                            }
                          },
                        ),
                        // ? NUEVO: Seccié³n de operaciones (Movida arriba)
                        SeccionOperaciones(
                          servicio: widget.servicio,
                          actividadId: _actividadSeleccionadaId,
                          estaBloqueado:
                              _esServicioBloqueado ||
                              widget.servicio.estaAnulado,
                        ),
                        // Seccié³n de repuestos debe ir justo despué©s de los campos adicionales
                        const SizedBox(height: 24),
                        _buildSeccionRepuestos(),
                        const SizedBox(height: 24),
                        const SizedBox(height: 40),
                        // Botones movidos al AppBar; ya no se muestran aqué­
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  // ? NUEVO: Lé³gica de validacié³n de repuestos (3-State Logic)
  Future<bool> _validarRepuestos() async {
    // 1. Si hay repuestos agregados -> OK
    if (_repuestosAsignados.isNotEmpty) {
      return true;
    }

    // 2. Si marcé³ "Suministraron" PERO la lista está vacé­a -> BLOQUEO
    if (_servicioEditado.suministraronRepuestos == true) {
      _mostrarError(
        '?? Has marcado "Repuestos Suministrados" pero la lista está vacé­a.\n\n'
        'Por favor agrega los repuestos o desmarca la casilla si no se utilizaron.',
      );
      return false;
    }

    // 3. Si NO marcé³ y está vacé­a -> CONFIRMACIéN (Olvido vs Realidad)
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('?? Confirmar sin Repuestos'),
                content: const Text(
                  'No has registrado ningéºn repuesto.\n\n'
                  '¿Confirmas que este servicio se realizé³ SIN utilizar insumos ni refacciones?',
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () =>
                            Navigator.pop(context, false), // Cancelar (Olvido)
                    child: const Text('No, voy a agregar'),
                  ),
                  ElevatedButton(
                    onPressed:
                        () => Navigator.pop(context, true), // Confirmar (Real)
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sé­, continuar sin repuestos'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _actividadesService.dispose();
    super.dispose();
  }
}
