/// ============================================================================
/// ARCHIVO: servicio_create_page.dart
///
/// PROPéSITO: Página para crear nuevos servicios que:
/// - Presenta formulario completo para registro de servicios
/// - Valida campos obligatorios
/// - Integra selector de actividades
/// - Maneja la lé³gica de numeracié³n automática/manual
/// - Permite duplicar servicios existentes
///
/// USO: Se navega desde el boté³n (+) en ServiciosListPage
/// FUNCIéN: Formulario especializado para la creacié³n de nuevos servicios con todas las validaciones necesarias.
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Importar modelos y servicios
import '../models/servicio_model.dart';
import '../models/estado_model.dart';
import '../models/equipo_model.dart';

import '../services/servicios_api_service.dart';
import '../widgets/actividad_selector_widget.dart';
import '../services/actividades_service.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/servicios_sync_queue.dart';
import 'package:infoapp/core/utils/servicios_cache.dart';

// ? Importar widgets personalizados
import 'widgets/campo_autorizado_por.dart';
import 'widgets/campo_tipo_mantenimiento.dart';
import 'widgets/campo_equipo.dart';
import 'widgets/campo_centro_costo.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';

// ? NUEVO: Para validar inspecciones e integrar clientes
import '../../inspecciones/services/inspecciones_api_service.dart';
import '../../inspecciones/models/inspeccion_model.dart';
import '../../inspecciones/pages/inspeccion_detalle_page.dart';
import 'widgets/campo_cliente.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';

/// Página para crear un nuevo servicio
class ServicioCreatePage extends StatefulWidget {
  final ServicioModel?
  servicioParaDuplicar; // ? Parámetro opcional para duplicar

  const ServicioCreatePage({super.key, this.servicioParaDuplicar});

  @override
  State<ServicioCreatePage> createState() => _ServicioCreatePageState();
}

class _ServicioCreatePageState extends State<ServicioCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controllers para los campos de texto
  final TextEditingController _ordenClienteController = TextEditingController();
  final TextEditingController _numeroServicioController =
      TextEditingController();
  final TextEditingController _fechaIngresoController = TextEditingController();

  // Estados del formulario
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _error;

  // Datos para el formulario
  // List<EstadoModel> _estados = []; // Eliminado: no se usa directamente
  EstadoModel? _estadoInicial;

  // ? Valores seleccionados - Usando tipos correctos para widgets personalizados
  int? _funcionarioSeleccionado;
  int? _clienteId; // ? NUEVO: ID del cliente
  String? _clienteNombre; // ✅ NUEVO: Para la modal de confirmación
  String? _tipoMantenimientoSeleccionado;
  EquipoModel? _equipoSeleccionado; // ? Cambio: ahora es EquipoModel completo
  int? _actividadSeleccionada; // ID de la actividad seleccionada
  DateTime? _fechaIngresoSeleccionada;
  String? _centroCostoSeleccionado; // ? Centro de costo seleccionado

  // Configuracié³n del néºmero de servicio
  bool _puedeEditarNumeroServicio = false;
  int? _siguienteNumeroServicio;
  
  // ? NUEVO: Cache para evitar revalidaciones innecesarias
  int? _ultimoEquipoValidado;
  int? _ultimaActividadValidada;
  
  // ? NUEVO: Trackear actividad pendiente encontrada para vincular despué©s
  ActividadInspeccionModel? _actividadPendienteEncontrada;

  // Llaves para scrolling automático en caso de error
  final GlobalKey _clienteKey = GlobalKey();
  final GlobalKey _equipoKey = GlobalKey();
  final GlobalKey _actividadKey = GlobalKey();
  final GlobalKey _infoBasicaKey = GlobalKey();
  final GlobalKey _detallesKey = GlobalKey();

  // Controlador de scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _inicializarFormulario();
  }

  @override
  void dispose() {
    _ordenClienteController.dispose();
    _numeroServicioController.dispose();
    _fechaIngresoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Helper para scroll suave a una llave (sección) específica
  void _scrollToKey(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Scroll hasta que el elemento esté un poco por debajo del tope
      );
    }
  }

  /// Inicializar el formulario y cargar datos (SIMPLIFICADO)
  Future<void> _inicializarFormulario() async {
    setState(() {
      _isLoadingData = true;
      _error = null;
    });

    try {
      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline && !kIsWeb) {
        if (widget.servicioParaDuplicar != null) {
          _prePoblarCamposParaDuplicar();
        } else {
          _fechaIngresoSeleccionada = DateTime.now();
          _fechaIngresoController.text = _formatearFecha(
            _fechaIngresoSeleccionada!,
          );
        }
        _puedeEditarNumeroServicio = false;
        _siguienteNumeroServicio = 1;
        _configurarNumeroServicio();
        setState(() {
          _isLoadingData = false;
          _error = null;
        });
        return;
      }
      // ? Solo cargar estados y verificar néºmero (los widgets se encargan de cargar sus propios datos)
      await Future.wait([_cargarEstados(), _verificarNumeroServicio()]);

      // Si hay datos para duplicar, pre-poblar los campos
      if (widget.servicioParaDuplicar != null) {
        _prePoblarCamposParaDuplicar();
      } else {
        // Configurar fecha de ingreso por defecto
        _fechaIngresoSeleccionada = DateTime.now();
        _fechaIngresoController.text = _formatearFecha(
          _fechaIngresoSeleccionada!,
        );
      }

      // Configurar néºmero de servicio
      _configurarNumeroServicio();

//       print('? Formulario inicializado correctamente');
    } catch (e) {
      setState(() {
        _error = 'Error inicializando formulario: $e';
      });
//       print('? Error inicializando formulario: $e');
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  /// Cargar lista de estados
  Future<void> _cargarEstados() async {
    try {
      // _estados = await ServiciosApiService.listarEstados(); // Eliminado: no se usa
      _estadoInicial = await ServiciosApiService.obtenerEstadoInicial();
    } catch (e) {
      throw Exception('Error cargando estados: $e');
    }
  }

  /// Verificar configuracié³n del néºmero de servicio
  Future<void> _verificarNumeroServicio() async {
    try {
      final resultado = await ServiciosApiService.verificarPrimerServicio();

      if (resultado.isSuccess && resultado.data != null) {
        _puedeEditarNumeroServicio =
            resultado.data!['es_primer_servicio'] ?? false;
        _siguienteNumeroServicio = resultado.data!['siguiente_numero'] ?? 1;
      }
    } catch (e) {
      // Si hay error, usar configuracié³n por defecto
      _puedeEditarNumeroServicio = false;
      _siguienteNumeroServicio = 1;
    }
  }

  /// Pre-poblar campos cuando se duplica un servicio (CORREGIDO)
  void _prePoblarCamposParaDuplicar() {
    final servicio = widget.servicioParaDuplicar!;

//     print('?? Duplicando servicio:');
//     print('   - Orden cliente: ${servicio.ordenCliente}');
//     print('   - Tipo mantenimiento: ${servicio.tipoMantenimiento}');
//     print('   - ID Equipo: ${servicio.idEquipo}');
//     print('   - Autorizado por: ${servicio.autorizadoPor}');

    // Pre-poblar campos del formulario
    if (servicio.ordenCliente != null) {
      _ordenClienteController.text = servicio.ordenCliente!;
    }

    // ? Asignar valores (los widgets se encargarán de validar)
    _tipoMantenimientoSeleccionado = servicio.tipoMantenimiento;
    _funcionarioSeleccionado = servicio.autorizadoPor;
    _clienteId = servicio.clienteId; // ? NUEVO
    _actividadSeleccionada = servicio.actividadId;
    _centroCostoSeleccionado = servicio.centroCosto;

    // Para el equipo, necesitamos crear un EquipoModel temporal si no tenemos todos los datos
    if (servicio.idEquipo != null) {
      _equipoSeleccionado = EquipoModel(
        id: servicio.idEquipo!,
        nombre: servicio.equipoNombre ?? 'Equipo ${servicio.idEquipo}',
        placa: servicio.placa,
        nombreEmpresa: servicio.nombreEmp,
        // Los demás campos se llenarán cuando el widget cargue los datos completos
      );
    }

    // Configurar fecha de ingreso actual
    _fechaIngresoSeleccionada = DateTime.now();
    _fechaIngresoController.text = _formatearFecha(_fechaIngresoSeleccionada!);
  }

  /// Configurar néºmero de servicio
  void _configurarNumeroServicio() {
    if (_puedeEditarNumeroServicio) {
      _numeroServicioController.text =
          _siguienteNumeroServicio?.toString() ?? '1';
    } else {
      _numeroServicioController.text = 'Auto-generado';
    }
  }

  /// Formatear fecha para mostrar
  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  /// Seleccionar fecha de ingreso
  Future<void> _seleccionarFecha() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaIngresoSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (fechaSeleccionada != null) {
      setState(() {
        _fechaIngresoSeleccionada = fechaSeleccionada;
        _fechaIngresoController.text = _formatearFecha(fechaSeleccionada);
      });
    }
  }

  /// Crear servicio - SIN usar Provider (más robusto)
  Future<void> _crearServicio() async {
    final store = PermissionStore.instance;

    // 1. DISPARAR VALIDACIÓN DE TODOS LOS CAMPOS (Pone los campos en rojo si están vacíos)
    final bool formValid = _formKey.currentState!.validate();

    // 2. SCROLL AL PRIMER ERROR ENCONTRADO (En orden de arriba hacia abajo)

    // 0. Cliente
    if (_clienteId == null) {
      _scrollToKey(_clienteKey);
      if (!formValid) return; // Ya está en rojo, detener aquí
      _mostrarError('Por favor seleccione un cliente');
      return;
    }

    // 1. Equipo
    if (_equipoSeleccionado == null) {
      _scrollToKey(_equipoKey);
      if (!formValid) return;
      _mostrarError('Por favor seleccione un equipo');
      return;
    }

    // 2. Actividad
    if (_actividadSeleccionada == null) {
      _scrollToKey(_actividadKey);
      if (!formValid) return;
      String msg = 'La actividad a realizar es obligatoria.';
      if (!store.can('servicios_actividades', 'ver')) {
        msg += ' No tiene permisos para este campo, contacte al administrador.';
      }
      _mostrarError(msg);
      return;
    }

    // Si el form no es válido por otros campos (como orden_cliente en Info Básica)
    if (!formValid) {
      _scrollToKey(_infoBasicaKey);
      return;
    }

    // 3. Detalles (Tipo Mantenimiento, Centro Costo, Autorizado Por)
    // Estas validaciones manuales son para cuando el campo está oculto por permisos
    // y el validator del widget no se dispara o el usuario no puede verlo.
    
    if (_tipoMantenimientoSeleccionado == null || 
        _centroCostoSeleccionado == null || _centroCostoSeleccionado!.isEmpty ||
        _funcionarioSeleccionado == null) {
      _scrollToKey(_detallesKey);
      
      if (_tipoMantenimientoSeleccionado == null) {
        _mostrarError('El tipo de mantenimiento es obligatorio.');
      } else if (_centroCostoSeleccionado == null || _centroCostoSeleccionado!.isEmpty) {
        _mostrarError('El Centro de Costo es obligatorio.');
      } else if (_funcionarioSeleccionado == null) {
        _mostrarError('Debe indicar quién autoriza el servicio.');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // âœ… NUEVO: Confirmar antes de proceder
      final bool? confirmado = await _mostrarConfirmacionDialog();
      if (confirmado != true) {
        setState(() => _isLoading = false);
        return;
      }

      // ? Si orden_cliente estÃ¡ vacÃ­a, enviar valor por defecto
      final ordenCliente =
          _ordenClienteController.text.trim().isEmpty
              ? 'PENDIENTE' // ? Valor por defecto simple
              : _ordenClienteController.text.trim();

      // Crear modelo del servicio
      final servicio = ServicioModel(
        ordenCliente: ordenCliente, // ? Siempre enviar algo
        fechaIngreso: _fechaIngresoSeleccionada?.toIso8601String(),
        autorizadoPor: _funcionarioSeleccionado,
        tipoMantenimiento: _tipoMantenimientoSeleccionado,
        centroCosto: _centroCostoSeleccionado,
        idEquipo: _equipoSeleccionado?.id,
        actividadId: _actividadSeleccionada,
        clienteId: _clienteId, // ? NUEVO
        estadoId: _estadoInicial?.id,
        oServicio:
            _puedeEditarNumeroServicio
                ? int.tryParse(_numeroServicioController.text)
                : null,
      );

//       print('?? Creando servicio con orden: "$ordenCliente"');

      // Verificar conectividad actual
      final isOnline = await ConnectivityService.instance.checkNow();

      if (!isOnline) {
        if (kIsWeb) {
          _mostrarError('En la web no se permite trabajar sin conexié³n.');
          return;
        }
        // Encolar para sincronizacié³n posterior
        await ServiciosSyncQueue.enqueueCreate(servicio);

        // Actualizar caché© local para que el nuevo servicio aparezca offline
        try {
          final lista = await ServiciosCache.loadList() ?? [];
          final servicioPendiente = servicio.copyWith(
            estadoNombre: servicio.estadoNombre ?? 'PENDIENTE',
          );
          lista.insert(0, servicioPendiente);
          await ServiciosCache.saveList(lista);
        } catch (_) {}

        _mostrarExito(
          'Sin conexié³n. El servicio (y personal si aplica) se guardé³ localmente y se sincronizará al reconectar.',
        );
        Navigator.pop(context, servicio);
        return;
      }

      final resultado = await ServiciosApiService.crearServicio(servicio);

      if (resultado.isSuccess && resultado.data != null) {
        // ? Asignar personal seleccionado si existe
        final nuevoServicio = resultado.data!;
        
        // Vincular actividad de inspeccié³n si existe
        if (_actividadPendienteEncontrada != null && nuevoServicio.id != null) {
          try {
            final vinculado = await InspeccionesApiService.vincularActividadAServicio(
              actividadInspeccionId: _actividadPendienteEncontrada!.id!,
              servicioId: nuevoServicio.id!,
            );
            if (vinculado) {
              debugPrint('Actividad de inspeccié³n vinculada al servicio');
            }
          } catch (e) {
            debugPrint('Error vinculando actividad de inspeccié³n: $e');
          }
        }
        
        _mostrarExito(
          _actividadPendienteEncontrada != null 
            ? 'Servicio #${nuevoServicio.oServicio} creado y vinculado a inspeccié³n'
            : 'Servicio #${nuevoServicio.oServicio} creado exitosamente'
        );

//         print('? Servicio creado: ${resultado.data!.oServicio}');

        // ? CRéTICO: Cerrar inmediatamente y devolver el servicio para que la lista se actualice
        if (mounted) {
          Navigator.pop(context, nuevoServicio);
        }
      } else {
        setState(() {
          _error = resultado.error ?? 'Error desconocido';
        });
//         print('? Error creando servicio: ${resultado.error}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error creando servicio: $e';
      });
//       print('? Excepcié³n creando servicio: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// âœ… NUEVO: Modal de confirmaciÃ³n premium
  Future<bool?> _mostrarConfirmacionDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      color: Theme.of(context).primaryColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Confirmar Creación',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Por favor verifique que los datos de Cliente y Equipo sean correctos antes de continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  
                  // Detalle de Cliente
                  _buildConfirmRow(
                    icon: PhosphorIcons.buildings(),
                    label: 'CLIENTE',
                    value: _clienteNombre ?? 'No seleccionado',
                  ),
                  const SizedBox(height: 16),
                  
                  // Detalle de Equipo
                  _buildConfirmRow(
                    icon: PhosphorIcons.truck(),
                    label: 'EQUIPO',
                    value: _equipoSeleccionado?.nombre ?? 'No seleccionado',
                  ),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('CORREGIR'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('CONFIRMAR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mostrar mensaje de éxito
  void _mostrarExito(String mensaje) {
    NetErrorMessages.showMessage(context, mensaje, success: true);
  }

  /// Mostrar mensaje de error
  void _mostrarError(String mensaje) {
    NetErrorMessages.showMessage(context, mensaje, success: false);
  }
  
  /// Validar si existe inspección activa con la actividad pendiente
  Future<void> _validarInspeccionActiva(int? equipoId, int? actividadId) async {
    if (!mounted) return;
    if (equipoId == null || actividadId == null) return;

    // Evitar validacié³n duplicada inmediata
    if (_ultimoEquipoValidado == equipoId && _ultimaActividadValidada == actividadId) {
      return;
    }

    try {
      final resultado = await InspeccionesApiService.listarInspecciones(
        equipoId: equipoId,
        limite: 5, 
      );

      final inspecciones = resultado['inspecciones'] as List<dynamic>;
      final activas = inspecciones; 

      if (!mounted) return;
      if (activas.isEmpty) return;

      bool encontrada = false;

      for (final inspeccion in activas) {
         if (inspeccion.id == null) continue;

         final detalle = await InspeccionesApiService.obtenerInspeccion(inspeccion.id!);
         
         if (detalle.actividades == null) continue;

         try {
           final actividadPendiente = detalle.actividades!.firstWhere(
             (a) {
               final match = a.actividadId == actividadId;
               final noAutorizada = a.autorizada != true;
               final sinServicio = a.servicioId == null;
               
               return match && noAutorizada && sinServicio;
             },
           );
           
           if (mounted) {
             encontrada = true;
             _actividadPendienteEncontrada = actividadPendiente;
             _mostrarAlertaInspeccion(detalle, actividadPendiente.actividadNombre);
           }
           
           _ultimoEquipoValidado = equipoId;
           _ultimaActividadValidada = actividadId;
           return; 
         } catch (_) {
           continue;
         }
      }

    } catch (e) {
      debugPrint('Error validando inspección: $e');
    }
  }

  /// ? NUEVO: Mostrar alerta cuando se encuentra inspección con actividad pendiente
  void _mostrarAlertaInspeccion(InspeccionModel inspeccion, String? actividadNombre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Actividad Pendiente')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La inspección ${inspeccion.oInspe} tiene esta actividad pendiente de autorización:',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '👉 ${actividadNombre ?? 'Actividad'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Equipo: ${inspeccion.equipoNombre}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '¿Deseas ir a la inspección para autorizarla?',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Crear de Todas Formas'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InspeccionDetallePage(
                    inspeccionId: inspeccion.id!,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Ir a Inspección'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          widget.servicioParaDuplicar != null
              ? 'Duplicar Servicio'
              : 'Crear Nuevo Servicio',
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoadingData
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando datos del formulario...'),
                  ],
                ),
              )
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.wrench(),
                      size: 32,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _inicializarFormulario,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mostrar información si es duplicación
                      if (widget.servicioParaDuplicar != null) ...[
                        Container(
                          key: const ValueKey('duplicate_info'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.copy,
                                    color: Colors.blue.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Duplicando servicio ${widget.servicioParaDuplicar!.numeroServicioFormateado}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Los datos del servicio original han sido pre-poblados. '
                                'Revisa y modifica segéºn sea necesario.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      _buildSeccionCard(
                        key: _clienteKey,
                        titulo: 'Información del Servicio',
                        icono: Icons.business,
                        children: [
                          CampoCliente(
                            clienteSeleccionado: _clienteId,
                            onChanged: (cliente) {
                              setState(() {
                                _clienteId = cliente?.id;
                                _clienteNombre = cliente?.nombreCompleto; // âœ… NUEVO
                                // Resetear dependencias para forzar nueva selecciÃ©n vÃ¡lida filtrada
                                _equipoSeleccionado = null;
                                _funcionarioSeleccionado = null;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor seleccione un cliente';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Seleccione el cliente para este servicio.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Informacié³n básica
                      // Selector de equipo primero
                      _buildSeccionCard(
                        key: _equipoKey,
                        titulo: 'Equipo',
                        icono: Icons.precision_manufacturing,
                        children: [
                          CampoEquipo(
                            equipoSeleccionado: _equipoSeleccionado?.id,
                            clienteId: _clienteId,
                            onChanged: (equipo) {
                              setState(() {
                                _equipoSeleccionado = equipo;
                              });
                              // ? Validar si hay actividad seleccionada
                              if (equipo != null && _actividadSeleccionada != null) {
                                _validarInspeccionActiva(equipo.id, _actividadSeleccionada!);
                              }
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor seleccione un equipo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Seleccione el equipo. Filtre por equipo, cé³digo o empresa.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ? Actividad a realizar - SEGUNDO CAMPO para validación temprana (Con Permisos)
                      Builder(
                        builder: (context) {
                          final store = PermissionStore.instance;
                          final canView = store.can('servicios_actividades', 'ver');
                          final canList = store.can('servicios_actividades', 'listar');

                          if (!canView) return const SizedBox.shrink();

                          return Column(
                            children: [
                              _buildSeccionCard(
                                key: _actividadKey,
                                titulo: 'Actividad a Realizar',
                                icono: Icons.build_circle,
                                children: [
                                  FormField<int>(
                                    initialValue: _actividadSeleccionada,
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Por favor seleccione una actividad';
                                      }
                                      return null;
                                    },
                                    builder: (fieldState) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ChangeNotifierProvider(
                                            create: (_) => ActividadesService()..cargarActividades(),
                                            child: ActividadSelectorWidget(
                                              servicio: ServicioModel(
                                                id: null,
                                                actividadId: _actividadSeleccionada,
                                              ),
                                              onChanged: canList
                                                  ? (actividad) {
                                                      setState(() {
                                                        _actividadSeleccionada = actividad?.id;
                                                      });
                                                      fieldState.didChange(_actividadSeleccionada);
                                                      
                                                      // Validar inspección activa
                                                      if (actividad != null && _equipoSeleccionado != null) {
                                                        _validarInspeccionActiva(_equipoSeleccionado!.id, actividad.id);
                                                      }
                                                    }
                                                  : (_) {}, // Dummy function for non-nullable param
                                              enabled: canList,
                                            ),
                                          ),
                                          if (!canList)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Row(
                                                children: [
                                                  Icon(PhosphorIcons.lockKey(), size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Sin permiso para cambiar actividades',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (fieldState.hasError)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6, left: 4),
                                              child: Text(
                                                fieldState.errorText!,
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Seleccione la actividad que se realizará en este servicio.',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),

                      // Información básica
                      _buildSeccionCard(
                        key: _infoBasicaKey,
                        titulo: 'Información Básica',
                        icono: Icons.info_outline,
                        children: [
                          // Néºmero de servicio
                          _buildCampoNumeroServicio(),
                          const SizedBox(height: 16),

                          // Orden del cliente
                          _buildCampoOrdenCliente(),
                          const SizedBox(height: 16),

                          // Fecha de ingreso
                          _buildCampoFecha(),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ? Detalles del servicio - USANDO WIDGETS PERSONALIZADOS
                      _buildSeccionCard(
                        key: _detallesKey,
                        titulo: 'Detalles del Servicio',
                        icono: Icons.build,
                        children: [
                          // ? Campo Autorizado por - Con Permisos Escalonados
                          Builder(
                            builder: (context) {
                              final store = PermissionStore.instance;
                              final canView = store.can('servicios_autorizado_por', 'ver');
                              final canList = store.can('servicios_autorizado_por', 'listar');

                              if (!canView) return const SizedBox.shrink();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CampoAutorizadoPor(
                                    autorizadoPor: _funcionarioSeleccionado,
                                    onChanged: (valor) {
                                      setState(() => _funcionarioSeleccionado = valor);
                                    },
                                    enabled: canList,
                                    empresa: _equipoSeleccionado?.nombreEmpresa,
                                    clienteId: _clienteId,
                                    validator: (valor) => valor == null ? 'Seleccione quien autoriza' : null,
                                  ),
                                  if (!canList)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, left: 4),
                                      child: Row(
                                        children: [
                                          Icon(PhosphorIcons.lockKey(), size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Lectura solamente (sin permiso de gestión)',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),

                          // ? Campo Tipo de Mantenimiento - Con Permisos Escalonados
                          Builder(
                            builder: (context) {
                              final store = PermissionStore.instance;
                              final canView = store.can('servicios_tipo_mantenimiento', 'ver');
                              final canList = store.can('servicios_tipo_mantenimiento', 'listar');
                              final canCreate = store.can('servicios_tipo_mantenimiento', 'crear');
                              final canDelete = store.can('servicios_tipo_mantenimiento', 'eliminar');

                              if (!canView) return const SizedBox.shrink();

                              return Column(
                                children: [
                                  CampoTipoMantenimiento(
                                    tipoSeleccionado: _tipoMantenimientoSeleccionado,
                                    onChanged: (valor) {
                                      setState(() => _tipoMantenimientoSeleccionado = valor);
                                    },
                                    enabled: canList,
                                    canCreate: canCreate,
                                    canDelete: canDelete,
                                    validator: (valor) => valor == null ? 'Seleccione un tipo' : null,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),
                          // ? Campo Centro de Costo - Con Permisos Escalonados
                          Builder(
                            builder: (context) {
                              final store = PermissionStore.instance;
                              final canView = store.can('servicios_centro_costo', 'ver');
                              final canList = store.can('servicios_centro_costo', 'listar');
                              final canCreate = store.can('servicios_centro_costo', 'crear');
                              final canDelete = store.can('servicios_centro_costo', 'eliminar');

                              if (!canView) return const SizedBox.shrink();

                              return CampoCentroCosto(
                                centroSeleccionado: _centroCostoSeleccionado,
                                onChanged: (centro) {
                                  setState(() => _centroCostoSeleccionado = centro);
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Seleccione un centro de costo';
                                  }
                                  return null;
                                },
                                enabled: canList,
                                canCreate: canCreate,
                                canDelete: canDelete,
                              );
                            },
                          ),
                          // ? Campo de actividad movido al inicio del formulario
                        ],
                      ),
                      const SizedBox(height: 24),


                      // Botones de accié³n
                      _buildBotonesAccion(),
                    ],
                  ),
                ),
              ),
    );
  }

  /// Construir sección con card
  Widget _buildSeccionCard({
    required String titulo,
    required IconData icono,
    required List<Widget> children,
    Key? key,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
              Icon(icono, color: Theme.of(context).primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
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


  /// Campo néºmero de servicio
  Widget _buildCampoNumeroServicio() {
    return TextFormField(
      controller: _numeroServicioController,
      decoration: InputDecoration(
        labelText: 'Néºmero de Servicio',
        hintText:
            _puedeEditarNumeroServicio
                ? 'Ingrese el néºmero de servicio'
                : 'Se generará automáticamente',
        prefixIcon: const Icon(Icons.numbers),
        border: const OutlineInputBorder(),
        enabled: _puedeEditarNumeroServicio,
        suffixIcon:
            _puedeEditarNumeroServicio ? null : const Icon(Icons.auto_awesome),
      ),
      keyboardType: TextInputType.number,
      validator:
          _puedeEditarNumeroServicio
              ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese el néºmero de servicio';
                }
                if (int.tryParse(value) == null) {
                  return 'Ingrese un néºmero válido';
                }
                return null;
              }
              : null,
    );
  }

  /// Campo orden del cliente
  Widget _buildCampoOrdenCliente() {
    return TextFormField(
      controller: _ordenClienteController,
      decoration: const InputDecoration(
        labelText: 'Orden del Cliente',
        hintText: 'Ingrese la orden del cliente',
        prefixIcon: Icon(Icons.receipt),
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [UpperCaseTextFormatter()],
    );
  }

  /// Campo fecha de ingreso
  Widget _buildCampoFecha() {
    return TextFormField(
      controller: _fechaIngresoController,
      decoration: const InputDecoration(
        labelText: 'Fecha de Ingreso',
        hintText: 'Seleccione la fecha de ingreso',
        prefixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(),
      ),
      readOnly: true,
      onTap: _seleccionarFecha,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor seleccione la fecha de ingreso';
        }
        return null;
      },
    );
  }

  /// Botones de accié³n
  Widget _buildBotonesAccion() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _crearServicio,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(
                      widget.servicioParaDuplicar != null
                          ? 'Crear Copia'
                          : 'Crear Servicio',
                    ),
          ),
        ),
      ],
    );
  }

  /// Parsear color desde hex
  Color _parseColor(String? hexColor) {
    if (hexColor == null || !hexColor.startsWith('#') || hexColor.length != 7) {
      return Colors.grey;
    }
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return Colors.grey;
    }
  }
}
