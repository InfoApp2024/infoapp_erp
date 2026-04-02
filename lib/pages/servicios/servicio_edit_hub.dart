/// ============================================================================
/// ARCHIVO: servicio_edit_hub.dart
///
/// PROPSITO: Hub central para la edicin de servicios (Versin 2.0 - UMW).
/// - Implementa el patrn Unified Maintenance Workspace.
/// - Gestiona pestaas: Info, Tareas, Recursos, Bitcora.
/// - Controla la lgica de negocio replicada de ServicioEditPage para seguridad.
///
/// USO: Reemplaza a ServicioEditPage cuando se activa la flag V2.
/// ============================================================================
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';

// Importar el formulario y modelos
import 'package:infoapp/pages/servicios/forms/servicio_form.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campos_adicionales.dart';

import 'package:infoapp/pages/servicios/workflow/estado_workflow_models.dart';
import 'package:infoapp/pages/servicios/workflow/estado_workflow_service.dart';
import 'package:infoapp/pages/servicios/services/actividades_service.dart';

// Imports para repuestos y staff
import 'package:provider/provider.dart';
import 'package:infoapp/pages/servicios/providers/operaciones_provider.dart';
import 'package:infoapp/pages/servicios/models/servicio_repuesto_model.dart';
import 'package:infoapp/pages/servicios/services/servicio_repuestos_api_service.dart';
import 'package:infoapp/pages/servicios/widgets/inventory_selection_modal.dart';
import 'package:infoapp/pages/servicios/models/servicio_staff_model.dart';
import 'package:infoapp/pages/servicios/widgets/user_selection_modal.dart';
import 'package:infoapp/utils/connectivity_service.dart';

// UMW Widgets
import 'package:infoapp/pages/servicios/widgets/umw/umw_header.dart';
import 'package:infoapp/pages/servicios/widgets/umw/umw_info_tab.dart';
import 'package:infoapp/pages/servicios/widgets/umw/umw_tasks_tab.dart';
import 'package:infoapp/pages/servicios/widgets/umw/umw_resources_tab.dart';
import 'package:infoapp/pages/servicios/widgets/umw/umw_flow_tab.dart';
import 'package:infoapp/pages/servicios/widgets/umw/umw_firmas_tab.dart';
import 'package:infoapp/pages/firmas/pages/firma_captura_screen.dart';
import 'package:infoapp/pages/firmas/controllers/firmas_controller.dart';
import 'package:infoapp/pages/servicios/controllers/branding_controller.dart';
import 'package:infoapp/pages/servicios/widgets/umw/umw_tiempos_tab.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

class ServicioEditHub extends StatefulWidget {
  final ServicioModel servicio;

  const ServicioEditHub({super.key, required this.servicio});

  @override
  State<ServicioEditHub> createState() => _ServicioEditHubState();
}

class _ServicioEditHubState extends State<ServicioEditHub> {
  final GlobalKey<ServicioFormState> _formKey = GlobalKey<ServicioFormState>();
  final GlobalKey<CamposAdicionalesServiciosState> _camposAdicionalesKey =
      GlobalKey<CamposAdicionalesServiciosState>();

  // Estado del Servicio
  late ServicioModel _servicioEditado;
  bool _isLoading = false;
  bool _isUpdating = false;
  final bool _isAnulling = false;
  bool _hasChanges = false;
  bool _formFullyInitialized = false;

  // Recursos
  List<ServicioStaffModel> _staffAsignado = [];
  bool _isLoadingStaff = false;
  List<ServicioRepuestoModel> _repuestosAsignados = [];
  bool _isLoadingRepuestos = false;

  // Actividades
  final ActividadesService _actividadesService = ActividadesService();
  int? _actividadSeleccionadaId;

  // Workflow
  List<WorkflowTransicionDef> _accionesDisponibles = [];
  bool _esServicioBloqueado = false;

  // Auditoría (SoD)
  bool _isAuditor = false;
  bool _canEditClosedOps = false;
  int? _currentUserId;

  // Cache y Conectividad
  bool _isOnline = true;

  TabController? _tabController; // ✅ NUEVO

  @override
  void initState() {
    super.initState();
    _servicioEditado = widget.servicio;
    _checkConnectivity();
    _cargarDatosIniciales();
  }

  // ✅ NUEVO: Listener para refrescar auditoría al cambiar de pestaña
  void _onTabChanged() {
    if (_tabController == null) return;

    final branding = context.read<BrandingController>().branding;
    final verTiempos = branding?.verTiempos ?? false;

    // El índice de Evidencias suele ser 3 (Info=0, Op=1, Rec=2, Evid=3)
    // Pero si verTiempos es true, hay 6 pestañas en total.
    // Vamos a identificarlo por el nombre de la pestaña o simplemente refrescar en 3.
    if (_tabController!.index == 3) {
      _cargarAuditoriaInfo();
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    // IMPORTANTE: NO llamar a _tabController?.dispose() porque es propiedad del DefaultTabController
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await ConnectivityService.instance.checkNow();
    if (mounted) setState(() => _isOnline = isOnline);
  }

  void _cargarDatosIniciales() {
    _cargarStaffAsignado();
    _cargarRepuestosAsignados();
    _verificarBloqueo();
    _cargarAuditoriaInfo(); // ✅ NUEVO: Cargar auditoría SoD
    _cargarDatosSesion(); // ✅ NUEVO: Cargar datos del usuario actual

    // ✅ NUEVO: Cargar transiciones directamente desde el Hub al iniciar.
    // Antes se delegaba al ServicioForm, pero causaba duplicados por race conditions.
    _recargarAccionesDisponibles();
  }

  Future<void> _cargarDatosSesion() async {
    try {
      final userData = await AuthService.getUserData();

      bool auditor = false;
      if (userData != null) {
        final rol = (userData['rol'] ?? '').toString().toLowerCase();
        final esAuditorFlag =
            (userData['es_auditor'] == 1 ||
                userData['es_auditor'] == '1' ||
                userData['es_auditor'] == true);
        final esAuditorRol = rol.contains('auditor') || rol.contains('gerente');
        auditor = esAuditorFlag || esAuditorRol;

        if (mounted) {
          setState(() {
            _currentUserId = userData['id'];
            _isAuditor = auditor;
          });
        }
      }

      // Siempre intentar refrescar perfil para estar seguros del estado más reciente

      final res = await ServiciosApiService.refreshUserData();
      if (res.isSuccess && res.data != null && mounted) {
        final freshData = res.data!;

        // DEBUG: Imprimir llaves para verificar casing (mayúsculas/minúsculas)

        final freshRol = (freshData['rol'] ?? '').toString().toLowerCase();
        final freshFlag =
            (freshData['es_auditor'] == 1 ||
                freshData['es_auditor'] == '1' ||
                freshData['es_auditor'] == true ||
                freshData['ES_AUDITOR'] == 1 ||
                freshData['ES_AUDITOR'] == '1' ||
                freshData['ES_AUDITOR'] == true);
        final isFreshAuditor =
            freshFlag ||
            freshRol.contains('auditor') ||
            freshRol.contains('gerente');

        final freshCanEditClosed =
            (freshData['can_edit_closed_ops'] == 1 ||
                freshData['can_edit_closed_ops'] == '1' ||
                freshData['can_edit_closed_ops'] == true);

        setState(() {
          _isAuditor = isFreshAuditor;
          _canEditClosedOps = freshCanEditClosed;
        });

        // Si el estado de auditor cambió o se refrescó con éxito, re-cargar info de auditoría del servicio
        _cargarAuditoriaInfo();
      } else {}
    } catch (e) {}
  }

  Future<void> _verificarBloqueo() async {
    // Validar contra estados finales para evitar edición
    if (_servicioEditado.estaAnulado) {
      if (mounted) setState(() => _esServicioBloqueado = true);
      return;
    }

    final lowerState = _servicioEditado.estadoNombre?.toLowerCase() ?? '';
    bool esEstadoFinal =
        lowerState.contains('finaliz') ||
        lowerState.contains('termin') ||
        lowerState.contains('cerrado') ||
        lowerState.contains('cancelado') ||
        lowerState.contains('legalizado');

    if (esEstadoFinal) {
      if (mounted) {
        setState(() => _esServicioBloqueado = !_canEditClosedOps);
      }
    }
  }

  // --- Lógica de Auditoría SoD (NUEVO) ---
  Future<void> _cargarAuditoriaInfo() async {
    if (_servicioEditado.id == null) return;

    final result = await ServiciosApiService.checkAuditoria(
      _servicioEditado.id!,
    );
    if (result.isSuccess && result.data != null) {
      if (mounted) {
        setState(() {
          _servicioEditado = _servicioEditado.copyWith(
            auditoriaInfo: result.data,
          );
        });
      }
    }
  }

  Future<void> _registrarAuditoria(String comentario) async {
    if (_servicioEditado.id == null) return;

    setState(() => _isUpdating = true);
    final result = await ServiciosApiService.registrarAuditoria(
      servicioId: _servicioEditado.id!,
      comentario: comentario,
    );

    if (result.isSuccess) {
      await _cargarAuditoriaInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auditoría aprobada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) _mostrarError(result.error);
    }
    setState(() => _isUpdating = false);
  }

  bool _getOperacionStatus(int opId) {
    try {
      final provider = Provider.of<OperacionesProvider>(context, listen: false);
      return provider.operaciones.any((o) => o.id == opId && o.estaFinalizada);
    } catch (_) {
      return false;
    }
  }

  // --- Lgica de Staff ---
  Future<void> _cargarStaffAsignado() async {
    if (!mounted) return;
    setState(() => _isLoadingStaff = true);
    try {
      final response = await ServiciosApiService.listarStaffDeServicio(
        _servicioEditado.id!,
      );
      if (mounted) {
        setState(() => _staffAsignado = response);
      }

      // ✅ SINCRONIZAR: Recargar el servicio completo para obtener personal_confirmado actualizado
      // Esto dispara el auto-avance de estado si el workflow engine lo procesó
      final resServicio = await ServiciosApiService.obtenerServicio(_servicioEditado.id!);
      if (mounted && resServicio.data != null) {
        setState(() {
          _servicioEditado = resServicio.data!;
          _verificarBloqueo();
        });
        // Recargar acciones por si el estado cambió automáticamente
        await _recargarAccionesDisponibles();
      }
    } finally {
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

  Future<void> _gestionarStaff({int? fixedOperacionId}) async {
    final resultado = await showDialog(
      context: context,
      builder:
          (context) => UserSelectionModal(
            servicioId: _servicioEditado.id!,
            staffYaAsignado: _staffAsignado,
            fixedOperacionId: fixedOperacionId,
            enabled: fixedOperacionId == null ||
                !_getOperacionStatus(fixedOperacionId) ||
                _canEditClosedOps,
          ),
    );

    if (resultado == true) {
      _cargarStaffAsignado(); // Recargar tras cambios
      _cargarRepuestosAsignados(); // Recargar repuestos también por si acaso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal actualizado correctamente')),
      );
    }
  }

  // --- Lógica de Repuestos ---
  Future<void> _cargarRepuestosAsignados() async {
    if (!mounted) return;
    setState(() => _isLoadingRepuestos = true);
    try {
      final response =
          await ServicioRepuestosApiService.listarRepuestosDeServicio(
            servicioId: _servicioEditado.id!,
          );
      if (mounted && response.success) {
        setState(() => _repuestosAsignados = response.data?.repuestos ?? []);
      }
    } finally {
      if (mounted) setState(() => _isLoadingRepuestos = false);
    }
  }


  Future<void> _gestionarRepuestos({int? fixedOperacionId}) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => InventorySelectionModal(
            servicioId: _servicioEditado.id!,
            repuestosYaAsignados: _repuestosAsignados,
            onRepuestosSeleccionados:
                (list) => setState(() => _repuestosAsignados = list),
            onRepuestosActualizados:
                () => _cargarRepuestosAsignados(), // Callback opcional
            fixedOperacionId: fixedOperacionId,
            enabled: fixedOperacionId == null ||
                !_getOperacionStatus(fixedOperacionId) ||
                _canEditClosedOps,
          ),
    );

    if (resultado == true) {
      _cargarRepuestosAsignados();
    }
  }

  Future<void> _eliminarRepuesto(ServicioRepuestoModel repuesto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar Repuesto'),
            content: Text('Seguro que deseas eliminar ${repuesto.itemNombre}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      // Llamada API eliminar
      try {
        await ServicioRepuestosApiService.eliminarRepuestoDeServicio(
          servicioRepuestoId: repuesto.id!,
        );
        _cargarRepuestosAsignados();
      } catch (e) {
        _handleError('Error eliminando repuesto: $e');
      }
    }
  }

  void _handleError(String message) {
    if (!mounted) return;

    String friendlyMessage = message;

    // Si contiene JSON de error del backend, intentar extraer solo el 'message'
    if (message.contains('{"success":false')) {
      try {
        final startIndex = message.indexOf('{');
        final jsonStr = message.substring(startIndex);
        final data = json.decode(jsonStr);
        if (data is Map && data.containsKey('message')) {
          friendlyMessage = data['message'];
        }
      } catch (_) {
        // Ignorar error de parseo y usar original
      }
    } else {
      // Limpiar prefijo "Exception: Error HTTP 403: " si existe
      friendlyMessage = friendlyMessage.replaceAll(
        RegExp(r'^Exception: Error HTTP \d+: '),
        '',
      );
    }

    final lowerMessage = friendlyMessage.toLowerCase();
    bool isBlocked =
        lowerMessage.contains('legalizado') ||
        lowerMessage.contains('final') ||
        lowerMessage.contains('cancelado') ||
        lowerMessage.contains('terminal');

    if (isBlocked) {
      friendlyMessage =
          'No se permiten realizar cambios en este servicio porque ya se encuentra en un estado final (LEGALIZADO/CANCELADO).\n\n'
          'Si necesitas hacer un ajuste, debes solicitar al área administrativa que retornen el servicio desde Gestión Financiera.';
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  isBlocked ? Icons.lock : Icons.error_outline,
                  color: isBlocked ? Colors.orange : Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  isBlocked ? 'Acción Bloqueada' : 'Error',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(friendlyMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _onSuministraronRepuestosChanged(bool? value) async {
    setState(() {
      _servicioEditado = _servicioEditado.copyWith(
        suministraronRepuestos: value,
      );
    });
    // Aquí se debería guardar el cambio en el backend inmediatamente o al guardar todo
    // Por compatibilidad, lo guardamos al guardar el formulario completo, pero
    // la UI necesita reflejarlo.
  }

  // ✅ NUEVO: Confirmar repuestos completados
  Future<void> _confirmarRepuestos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Repuestos'),
            content: const Text(
              '¿Ha terminado de agregar todos los repuestos necesarios?\n\n'
              'Esta acción marcará la sección como completa y permitirá que el servicio avance de estado automáticamente.',
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

    if (confirm == true) {
      try {
        final result = await ServiciosApiService.confirmarTrigger(
          servicioId: _servicioEditado.id!,
          triggerType: 'repuestos',
        );

        if (result.isSuccess) {
          setState(() {
            _servicioEditado = _servicioEditado.copyWith(
              suministraronRepuestos: true,
            );
          });

          // ✅ Recargar el servicio completo para obtener el nuevo estado del trigger
          final servicioActualizado = await ServiciosApiService.obtenerServicio(
            _servicioEditado.id!,
          );
          if (servicioActualizado.isSuccess &&
              servicioActualizado.data != null) {
            setState(() {
              _servicioEditado = servicioActualizado.data!;
            });
            // Recargar acciones disponibles con el nuevo estado
            _recargarAccionesDisponibles();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Repuestos confirmados. El servicio puede avanzar de estado.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(
            result.error ?? result.message ?? 'Error desconocido',
          );
        }
      } catch (e) {
        if (mounted) {
          _mostrarError(e);
        }
      }
    }
  }

  Future<void> _confirmarFotos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Fotos de Evidencia'),
            content: const Text(
              '¿Ha terminado de subir todas las fotos de evidencia necesarias?\n\n'
              'Esta acción marcará la sección como completa y permitirá que el servicio avance de estado automáticamente.',
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

    if (confirm == true) {
      try {
        final result = await ServiciosApiService.confirmarTrigger(
          servicioId: _servicioEditado.id!,
          triggerType: 'fotos',
        );

        if (result.isSuccess) {
          // Recargar el servicio completo para obtener el nuevo estado
          final servicioActualizado = await ServiciosApiService.obtenerServicio(
            _servicioEditado.id!,
          );
          if (servicioActualizado.isSuccess &&
              servicioActualizado.data != null) {
            setState(() {
              _servicioEditado = servicioActualizado.data!;
            });
            _recargarAccionesDisponibles();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Fotos confirmadas. El servicio puede avanzar de estado.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(
            result.error ?? result.message ?? 'Error desconocido',
          );
        }
      } catch (e) {
        if (mounted) {
          _mostrarError(e);
        }
      }
    }
  }

  Future<void> _confirmarFirma() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Firma del Cliente'),
            content: const Text(
              '¿Ha obtenido la firma del cliente?\n\n'
              'Esta acción marcará la sección como completa y permitirá que el servicio avance de estado automáticamente.',
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

    if (confirm == true) {
      try {
        final result = await ServiciosApiService.confirmarTrigger(
          servicioId: _servicioEditado.id!,
          triggerType: 'firma',
        );

        if (result.isSuccess) {
          // Recargar el servicio completo para obtener el nuevo estado
          final servicioActualizado = await ServiciosApiService.obtenerServicio(
            _servicioEditado.id!,
          );
          if (servicioActualizado.isSuccess &&
              servicioActualizado.data != null) {
            setState(() {
              _servicioEditado = servicioActualizado.data!;
            });
            _recargarAccionesDisponibles();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Firma confirmada. El servicio puede avanzar de estado.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(
            result.error ?? result.message ?? 'Error desconocido',
          );
        }
      } catch (e) {
        if (mounted) {
          _mostrarError(e);
        }
      }
    }
  }

  // --- Lógica de Guardado y Transiciones ---

  Future<void> _actualizarServicio(ServicioModel servicioActualizado) async {
    setState(() => _isLoading = true);

    try {
      //  LOGICA DE GUARDADO: Llamar a la API
      final result = await ServiciosApiService.actualizarServicio(
        servicioActualizado,
      );

      if (result.isSuccess) {
        setState(() {
          _servicioEditado = servicioActualizado;
          _hasChanges = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(' Cambios guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Recargar datos dependientes
        _cargarDatosIniciales();
      } else {
        throw Exception(result.error ?? 'Error desconocido');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _mostrarError(e);
      }
    }
  }

  String _cleanError(dynamic e) {
    String msg = e.toString();

    // Remoción iterativa de prefijos comunes
    bool changed = true;
    while (changed) {
      changed = false;
      final prefixes = [
        'Exception: ',
        'Error: ',
        'Exception',
        'Error al confirmar trigger: ',
        'Error al cambiar estado: ',
        'Error al actualizar servicio: ',
      ];

      for (final p in prefixes) {
        if (msg.startsWith(p)) {
          msg = msg.replaceFirst(p, '');
          changed = true;
        }
      }
    }

    return msg.trim();
  }

  void _mostrarError(dynamic error) {
    final mensaje = _cleanError(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Recarga las acciones disponibles basándose en el estado actual del servicio
  Future<void> _recargarAccionesDisponibles() async {
    if (_servicioEditado.estadoNombre == null) return;

    final workflowService = EstadoWorkflowService();

    try {
      // Ensure workflow is loaded from backend (force reload to catch latest config changes)
      await workflowService.ensureLoaded(force: true);

      // Get available transitions for current state
      final acciones = workflowService.getAvailableTransitions(
        _servicioEditado.estadoNombre!,
      );

      if (mounted) {
        setState(() => _accionesDisponibles = acciones);
      }
    } catch (e) {
      // Silent fail - actions will remain empty if error
      if (mounted) {
        setState(() => _accionesDisponibles = []);
      }
    }
  }

  /// Solicita la razón de cancelación al usuario
  /// Retorna la razón si se confirma, null si se cancela
  Future<String?> _solicitarRazonCancelacion() async {
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
                const Text('Cancelar Servicio'),
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
                      'Motivo de la cancelación:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: razonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describa por qué se cancela el servicio...',
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
                child: const Text('Confirmar Cancelación'),
              ),
            ],
          ),
    );
  }

  Future<void> _ejecutarAccion(
    WorkflowTransicionDef accion,
    BuildContext hubContext,
  ) async {
    if (_isUpdating || _isAnulling) return;

    // ✅ NUEVO: Validar triggers antes de mostrar confirmación
    final triggerCode = accion.triggerCode;

    if (triggerCode != null && triggerCode != 'MANUAL') {
      final validationResult = _validateTriggerLocally(triggerCode);

      if (!validationResult.isValid) {
        await showDialog(
          context: hubContext,
          builder:
              (context) => AlertDialog(
                title: const Text('Requisito no cumplido'),
                content: Text(validationResult.message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                  if (validationResult.redirectTab != null)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        DefaultTabController.of(
                          hubContext,
                        ).animateTo(validationResult.redirectTab!);
                      },
                      child: Text(validationResult.redirectLabel ?? 'Ir'),
                    ),
                ],
              ),
        );
        return;
      }
    }

    // ✅ NUEVO: Validar auditoría SoD si se intenta pasar a LEGALIZADO
    if (accion.to.toUpperCase() == 'LEGALIZADO') {
      final audit = _servicioEditado.auditoriaInfo;
      if (audit != null && audit.requiereAuditoriaPendiente) {
        final verTiempos =
            context.read<BrandingController>().branding?.verTiempos ?? false;
        await showDialog(
          context: hubContext,
          builder:
              (context) => AlertDialog(
                title: const Text('Auditoría Pendiente'),
                content: Text(
                  'Este servicio requiere una auditoría financiera antes de ser legalizado.\n\n'
                  'Por favor, solicite a un auditor autorizado (ej: ${audit.auditorNombre ?? 'Gestor SoD'}) que realice la validación en la pestaña "Flujo".',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                  if (_isAuditor)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarConfirmacionAuditoriaLocal();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aprobar Ahora'),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      DefaultTabController.of(
                        hubContext,
                      ).animateTo(verTiempos ? 5 : 4); // Flow tab index
                    },
                    child: const Text('Ir a Auditoría'),
                  ),
                ],
              ),
        );
        return;
      }
    }

    // âœ… NUEVO: Si el estado destino es "Cancelado", solicitar razÃ³n obligatoria
    String? razonCancelacion;
    final esCancelacion = accion.toEstadoBase?.toUpperCase() == 'CANCELADO';

    if (esCancelacion) {
      // 📦 Validador de repuestos: Si hay cargados, deben devolverse al inventario
      if (_repuestosAsignados.isNotEmpty) {
        final bool? devolvio = await _mostrarAvisoDevolucionRepuestos();
        if (devolvio != true) return; // Usuario cancelÃ³ la devoluciÃ³n
      }

      razonCancelacion = await _solicitarRazonCancelacion();
      if (razonCancelacion == null) return; // Usuario cancelÃ³ la modal
    }

    // 1. Confirmar Acción
    final confirm = await showDialog<bool>(
      context: hubContext,
      builder:
          (context) => AlertDialog(
            title: Text(accion.nombre ?? 'Confirmar Acción'),
            content: Text(
              '¿Desea cambiar el estado del servicio a "${accion.to}"?',
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

    // ✅ Limpiar acciones inmediatamente para prevenir doble clic
    setState(() {
      _accionesDisponibles = [];
      _isUpdating = true;
    });

    try {
      // 2. Ejecutar Cambio en Backend
      final result = await ServiciosApiService.cambiarEstadoServicio(
        servicioId: _servicioEditado.id!,
        nuevoEstadoId: accion.toId ?? 0,
        estadoDestinoNombre: accion.to,
        triggerCode: accion.triggerCode,
        esAnulacion: esCancelacion,
        razonAnulacion: razonCancelacion,
      );

      if (result.isSuccess) {
        // 3. Recargar Servicio Completo para sincronizar estado
        final resServicio = await ServiciosApiService.obtenerServicio(
          _servicioEditado.id!,
        );
        if (resServicio.data != null) {
          setState(() {
            _servicioEditado = resServicio.data!;
            _verificarBloqueo();
          });

          // ✅ v12: Asegurar que los datos de auditoría y sesión también se refresquen tras éxito
          await _cargarDatosSesion();

          // ✅ Recargar acciones disponibles para el nuevo estado
          await _recargarAccionesDisponibles();

          ScaffoldMessenger.of(hubContext).showSnackBar(
            SnackBar(content: Text('Estado actualizado a: ${accion.to}')),
          );
        }
      } else {
        // ✅ NUEVO: Restaurar acciones si el backend rechazó el cambio (ej: falta documentación o auditoría)
        await _cargarDatosSesion(); // Refresca _isAuditor y auditoriaInfo
        await _recargarAccionesDisponibles();
        _mostrarError(result.error ?? 'Error al cambiar estado');
      }
    } catch (e) {
      _mostrarError(e);
      // En caso de error, restaurar las acciones
      await _recargarAccionesDisponibles();
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛡ï¸ GUARDIA DE SEGURIDAD: Verificar permiso de edición
    if (!PermissionStore.instance.can('servicios', 'actualizar')) {
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

    final branding = context.watch<BrandingController>().branding;
    final operacionesProvider = context.watch<OperacionesProvider>(); // ✅ NUEVO
    final verTiempos = branding?.verTiempos ?? false;
    final numTabs = verTiempos ? 6 : 5;

    return DefaultTabController(
      length: numTabs,
      child: Builder(
        builder: (hubCtx) {
          // ✅ MEJORA: Vincular el TabController de forma segura
          final newController = DefaultTabController.of(hubCtx);
          if (newController != _tabController) {
            _tabController?.removeListener(_onTabChanged);
            _tabController = newController;
            _tabController?.addListener(_onTabChanged);
          }

          return Scaffold(
              backgroundColor: Colors.grey[50], // Fondo suave
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: UmwHeader(
                          key: ValueKey(
                            '${_servicioEditado.estadoId}_${_servicioEditado.estadoNombre}',
                          ),
                          servicio: _servicioEditado,
                          isWeb: kIsWeb,
                          acciones: _accionesDisponibles,
                          onAccionPressed:
                              (a, btnCtx) => _ejecutarAccion(a, hubCtx),
                          onBackPressed: () => Navigator.of(hubCtx).pop(),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          // controller: _tabController, (Usar automático del DefaultTabController)
                          labelColor: Theme.of(hubCtx).primaryColor,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Theme.of(hubCtx).primaryColor,
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          tabs: [
                            Tab(icon: Icon(PhosphorIcons.info()), text: 'Info'),
                            Tab(
                              icon: Icon(PhosphorIcons.checkSquare()),
                              text: 'Operaciones y Adicionales',
                            ),
                            Tab(
                              icon: Icon(PhosphorIcons.users()),
                              text: 'Recursos',
                            ),
                            Tab(
                              icon: Icon(PhosphorIcons.images()),
                              text: 'Evidencias',
                            ),
                            Tab(
                              icon: Icon(PhosphorIcons.penNib()),
                              text: 'Firmas',
                            ),
                            if (verTiempos)
                              Tab(
                                icon: Icon(PhosphorIcons.clock()),
                                text: 'Tiempos',
                              ),
                          ],
                        ),
                      ),
                      pinned: true,
                    ),
                  ];
                },
                body: TabBarView(
                  // controller: _tabController, (Usar automtico del DefaultTabController)
                  children: [
                    // INFO TAB
                    UmwInfoTab(
                      content: Column(
                        children: [
                          ServicioForm(
                            key: _formKey,
                            // camposAdicionalesKey: _camposAdicionalesKey,
                            servicio: widget.servicio,
                            onSaved: _actualizarServicio,
                            onError: _mostrarError,
                            onInitialized: () {
                              setState(() => _formFullyInitialized = true);
                            },
                            isEditing: true,
                            enabled:
                                !_isUpdating &&
                                !_isAnulling &&
                                !_esServicioBloqueado,
                            actividadesService: _actividadesService,
                            actividadSeleccionadaId: _actividadSeleccionadaId,
                            onActividadChanged:
                                (id) => setState(() {
                                  _actividadSeleccionadaId = id;
                                  _hasChanges = true;
                                }),
                            // Las transiciones disponibles son cargadas exclusivamente por
                            // _recargarAccionesDisponibles() del hub (con force:true).
                            // Tener dos fuentes llenando _accionesDisponibles causaba botones duplicados
                            // cuando el caché del singleton tenía nombres de estados desactualizados.
                            onTransitionsLoaded: null,
                            onValidateRepuestos: () async => true, // Placeholder
                            onChanged: () {
                              if (_formFullyInitialized && !_hasChanges) {
                                setState(() => _hasChanges = true);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // TASKS TAB
                    UmwTasksTab(
                      servicio: _servicioEditado,
                      actividadId: _actividadSeleccionadaId,
                      estaBloqueado: _esServicioBloqueado,
                      camposAdicionalesKey: _camposAdicionalesKey,
                      staffAsignado: _staffAsignado,
                      repuestosAsignados: _repuestosAsignados,
                      onGestionarStaff:
                          (opId) => _gestionarStaff(fixedOperacionId: opId),
                      onGestionarRepuestos:
                          (opId) => _gestionarRepuestos(fixedOperacionId: opId),
                      onChanged: () {
                        if (_formFullyInitialized && !_hasChanges) {
                          setState(() => _hasChanges = true);
                        }
                      },
                    ),

                    // RESOURCES TAB
                    UmwResourcesTab(
                      servicio: _servicioEditado,
                      staffAsignado: _staffAsignado,
                      repuestosAsignados: _repuestosAsignados,
                      operaciones:
                          operacionesProvider
                              .operaciones, // ✅ NUEVO: Pasar la lista de operaciones
                      isLoadingStaff: _isLoadingStaff,
                      isLoadingRepuestos: _isLoadingRepuestos,
                      estaBloqueado: _esServicioBloqueado,
                      onGestionarStaff:
                          (opId) => _gestionarStaff(
                            fixedOperacionId: opId,
                          ), // ✅ CORRECCIÓN
                      onGestionarRepuestos:
                          (opId) => _gestionarRepuestos(
                            fixedOperacionId: opId,
                          ), // ✅ CORRECCIÓN
                      onEliminarRepuesto: _eliminarRepuesto,
                      onSuministraronRepuestosChanged:
                          _onSuministraronRepuestosChanged,
                      accionesDisponibles: _accionesDisponibles,
                      onConfirmarRepuestos: _confirmarRepuestos,
                      onConfirmarFotos: _confirmarFotos,
                      onConfirmarFirma: _confirmarFirma,
                    ),

                    // FLOW TAB (BITÁCORA)
                    UmwFlowTab(
                      servicio: _servicioEditado,
                      estaBloqueado: _esServicioBloqueado,
                      accionesDisponibles: _accionesDisponibles,
                      onAccionPressed: _ejecutarAccion,
                      isAnulling: _isAnulling,
                      onConfirmarFotos: _confirmarFotos,
                      onConfirmarFirma: _confirmarFirma,
                      onRegistrarAuditoria:
                          _isAuditor ? _registrarAuditoria : null, // ✅ NUEVO
                    ),

                    // FIRMAS TAB
                    UmwFirmasTab(
                      servicio: _servicioEditado,
                      estaBloqueado: _esServicioBloqueado,
                      accionesDisponibles: _accionesDisponibles,
                      onIniciarFirma: _iniciarProcesoFirma,
                      onConfirmarFirma: _confirmarFirma,
                    ),

                    // TIEMPOS TAB (CONDITIONAL)
                    if (verTiempos) UmwTiemposTab(servicio: _servicioEditado),
                  ],
                ),
              ),
              floatingActionButton:
                  _hasChanges && !_esServicioBloqueado
                      ? FloatingActionButton.extended(
                        onPressed: () async {
                          // 1. Guardar campos adicionales primero
                          bool camposGuardados = true;
                          if (_camposAdicionalesKey.currentState != null) {
                            camposGuardados =
                                await _camposAdicionalesKey.currentState!
                                    .guardarCamposAdicionales();
                          }

                          // 2. Si se guardaron (o no había), guardar el formulario principal
                          if (camposGuardados) {
                            _formKey.currentState?.guardarFormulario();
                          } else {
                            _mostrarError(
                              'Error al guardar campos adicionales. Revise los datos.',
                            );
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Cambios'),
                        backgroundColor: Theme.of(hubCtx).primaryColor,
                      )
                      : null,
              bottomNavigationBar:
                  (() {
                    final auditInfo = _servicioEditado.auditoriaInfo;
                    final REQUIERE = auditInfo?.requiereAuditoriaPendiente ?? false;

                    // ✅ v11: Detectar si el estado actual tiene alguna acción final (LEGALIZADO)
                    final tieneAccionFinal = _accionesDisponibles.any((a) {
                      final target = (a.to ?? '').toUpperCase();
                      final actionLabel = (a.nombre ?? '').toUpperCase();
                      return target.contains('LEGALIZ') ||
                          actionLabel.contains('LEGALIZ');
                    });

                    // ✅ v13: Solo mostrar si el estado actual es apto para el trámite final
                    final esApto = auditInfo?.esAptoParaLegalizado ?? false;
                    if (!REQUIERE || !tieneAccionFinal || !esApto) return null;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: Colors.red.shade700,
                      child: SafeArea(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.security_update_warning,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Esta operación requiere auditoría para cambiar de estado. ${_isAuditor
                                        ? (esApto
                                            ? 'Usted puede aprobarla.'
                                            : 'Pendiente de cerrar actividades.')
                                        : 'Por favor, solicite a un auditor autorizado${auditInfo?.auditorNombre != null ? " (ej: ${auditInfo!.auditorNombre})" : ""}'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_isAuditor) ...[
                              const SizedBox(width: 8),
                              // ✅ v8 – Escenario D: Tooltip cuando hay actividades pendientes
                              Tooltip(
                                message:
                                    esApto
                                        ? ''
                                        : 'Pendiente de cerrar actividades del servicio',
                                child: ElevatedButton(
                                  onPressed:
                                      esApto
                                          ? () {
                                            _mostrarConfirmacionAuditoriaLocal();
                                          }
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.red.shade700,
                                    disabledForegroundColor: Colors.grey[400],
                                    disabledBackgroundColor: Colors.white70,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  child: const Text(
                                    'APROBAR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  })(),
            );
          },
        ),
      );
    }

  void _mostrarConfirmacionAuditoriaLocal() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Aprobar Auditoría (SoD)'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Al aprobar, confirma que ha revisado los recursos y montos del servicio.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Comentario de Aprobación',
                      hintText: 'Ej: Se validan montos y recursos...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El comentario es obligatorio para aprobar.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    _registrarAuditoria(controller.text);
                  }
                },
                child: const Text('APROBAR Y FIRMAR'),
              ),
            ],
          ),
    );
  }

  // ✅ NUEVO: Validación local de triggers
  _TriggerValidationResult _validateTriggerLocally(String triggerCode) {
    switch (triggerCode) {
      case 'OS_REPUESTOS':
        if (_repuestosAsignados.isEmpty) {
          return _TriggerValidationResult(
            isValid: false,
            message:
                'Debe agregar repuestos antes de continuar con esta transición.',
            redirectTab: 2, // Resources tab
            redirectLabel: 'Ir a Recursos',
          );
        }
        if (_servicioEditado.suministraronRepuestos != true) {
          return _TriggerValidationResult(
            isValid: false,
            message:
                'Debe confirmar los repuestos antes de continuar.\n\nVaya a la pestaña Recursos y presione "Confirmar Repuestos".',
            redirectTab: 2, // Resources tab
            redirectLabel: 'Ir a Recursos',
          );
        }
        break;

      case 'ASIGNAR_PERSONAL':
        if (!_servicioEditado.isPersonalConfirmado) {
          return _TriggerValidationResult(
            isValid: false,
            message:
                'Debe asignar al menos un técnico antes de continuar.\n\nVaya a la pestaña "Personal" y asigne los técnicos correspondientes.',
            redirectTab: 1, // Personal tab
            redirectLabel: 'Ir a Personal',
          );
        }
        break;

      case 'FOTO_SUBIDA':
        final confirmedFotos = _servicioEditado.isFotosConfirmadas;
        if (!confirmedFotos) {
          return _TriggerValidationResult(
            isValid: false,
            message:
                'Debe subir y confirmar las fotos de evidencia antes de continuar.\n\nVaya a la pestaña "Evidencias" y presione "Confirmar Fotos".',
            redirectTab: 3, // Evidencias tab
            redirectLabel: 'Ir a Evidencias',
          );
        }
        break;

      case 'FIRMA_CLIENTE':
        final confirmedFirma = _servicioEditado.isFirmaConfirmada;
        if (!confirmedFirma) {
          return _TriggerValidationResult(
            isValid: false,
            message:
                'Debe obtener y confirmar la firma del cliente antes de continuar.\n\nVaya a la pestaña "Firmas" y presione "Iniciar Proceso de Entrega y Firma".',
            redirectTab: 4, // Firmas tab
            redirectLabel: 'Ir a Firmas',
          );
        }
        break;
    }

    return _TriggerValidationResult(isValid: true);
  }

  // ✅ NUEVO: Lógica centralizada de firma
  Future<void> _iniciarProcesoFirma() async {
    // 1. Validar si falta la fecha de finalización
    if (_servicioEditado.fechaFinalizacion == null ||
        (_servicioEditado.fechaFinalizacion?.trim().isEmpty ?? true)) {
      // Calcular fecha mínima (Fecha de ingreso)
      DateTime fechaMinima = DateTime.now();
      try {
        if (_servicioEditado.fechaIngreso != null) {
          fechaMinima = DateTime.parse(_servicioEditado.fechaIngreso!);
        }
      } catch (_) {}

      DateTime fechaInicial = DateTime.now();
      fechaMinima = DateTime(
        fechaMinima.year,
        fechaMinima.month,
        fechaMinima.day,
      );
      if (fechaInicial.isBefore(fechaMinima)) fechaInicial = fechaMinima;

      // Diálogo informativo
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Fecha de Finalización Requerida'),
              content: const Text(
                'El servicio no tiene registrada una fecha de finalización.\n\n'
                'Para proceder con la firma y entrega, es necesario registrar cuándo se terminó el trabajo. '
                'Por favor seleccione la fecha a continuación.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continuar'),
                ),
              ],
            ),
      );

      if (!mounted) return;

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: fechaInicial,
        firstDate: fechaMinima,
        lastDate: DateTime(2100),
        helpText: 'FECHA FINALIZACIÓN REQUERIDA',
      );

      if (picked == null) return;

      _mostrarCargando('Guardando fecha de finalización...');

      try {
        final String fechaStr = picked.toIso8601String().split('T')[0];
        final servicioActualizado = _servicioEditado.copyWith(
          fechaFinalizacion: fechaStr,
        );

        final result = await ServiciosApiService.actualizarServicio(
          servicioActualizado,
        );
        _ocultarCargando();

        if (result.isSuccess) {
          setState(() => _servicioEditado = servicioActualizado);
          _mostrarExito('Fecha registrada. Procediendo a firma...');
        } else {
          _mostrarError(result.error ?? 'Error al actualizar la fecha');
          return;
        }
      } catch (e) {
        _ocultarCargando();
        _mostrarError('Error inesperado: $e');
        return;
      }
    }

    // 2. Navegar a la pantalla de firma
    final resultFirma = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider(
              create: (_) => FirmasController(),
              child: FirmaCapturaScreen(servicio: _servicioEditado),
            ),
      ),
    );

    if (resultFirma == true) {
      // Recargar servicio tras firma
      final res = await ServiciosApiService.obtenerServicio(
        _servicioEditado.id!,
      );
      if (res.isSuccess && res.data != null) {
        setState(() => _servicioEditado = res.data!);
        _recargarAccionesDisponibles();
      }
    }
  }

  void _mostrarCargando(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(mensaje),
              ],
            ),
          ),
    );
  }

  void _ocultarCargando() {
    Navigator.pop(context);
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  // ✅ NUEVO: Diálogo informativo sobre devolución de repuestos
  Future<bool?> _mostrarAvisoDevolucionRepuestos() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(PhosphorIcons.package(), color: Colors.orange.shade800),
                const SizedBox(width: 8),
                const Text('Repuestos en Servicio'),
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
                        'Se detectaron ${_repuestosAsignados.length} repuestos asignados.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Al cancelar el servicio, estos recursos se devolverán automáticamente al inventario (Stock Positivo).',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('DETENER'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context, true); // Devolver true para indicar que se debe proceder
                },
                icon: Icon(PhosphorIcons.arrowClockwise()),
                label: const Text('ENTENDIDO, DEVOLVER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    ).then((doubleConfirm) async {
      if (doubleConfirm == true) {
        _mostrarCargando('Devolviendo repuestos al inventario...');
        try {
          final res = await ServicioRepuestosApiService.eliminarTodosRepuestosServicio(
            servicioId: _servicioEditado.id!,
            razon: 'CANCELACIÓN DEL SERVICIO',
          );
          _ocultarCargando();
          if (res.isSuccess) {
            await _cargarRepuestosAsignados();
            return true;
          } else {
            _mostrarError(res.error ?? 'Error devolviendo repuestos');
            return false;
          }
        } catch (e) {
          _ocultarCargando();
          _mostrarError('Error de conexión al devolver repuestos');
          return false;
        }
      }
      return false;
    });
  }

}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 16;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 16;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.grey[50],
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return _tabBar != oldDelegate._tabBar;
  }
}

// ✅ NUEVO: Clase helper para resultados de validación
class _TriggerValidationResult {
  final bool isValid;
  final String message;
  final int? redirectTab;
  final String? redirectLabel;

  _TriggerValidationResult({
    required this.isValid,
    this.message = '',
    this.redirectTab,
    this.redirectLabel,
  });
}
