/// ============================================================================
/// ARCHIVO: servicios_list_page.dart
///
/// PROPéSITO: Página principal del mé³dulo de servicios que:
/// - Muestra la lista completa de servicios usando ServiciosTabla
/// - Gestiona filtros y béºsquedas
/// - Maneja la navegacié³n a crear/editar/ver detalles
/// - Integra WebSocket para actualizaciones en tiempo real
/// - Controla el estado general de la lista (loading, errores, etc.)
/// - ? NUEVO: Carga y gestiona campos adicionales dinámicos
///
/// USO: Página principal accesible desde el menéº de la aplicacié³n
/// FUNCIéN: Es la página contenedora principal que orquesta todo el mé³dulo de servicios. Coordina la tabla,
/// los filtros, y las acciones del usuario.
/// ============================================================================
library;
// library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Importar páginas y servicios
import '../models/servicio_model.dart';
import '../services/servicios_api_service.dart';
import '../controllers/servicios_controller.dart';
import '../forms/servicio_create_page.dart';
import '../forms/servicio_detail_page.dart';
import 'package:provider/provider.dart';
import '../widgets/servicios_tabla.dart';
import 'package:infoapp/core/branding/theme_provider.dart';
import 'package:infoapp/config/module_column_config_modal.dart';
import 'package:infoapp/core/utils/module_utils.dart';
import '../models/campo_adicional_model.dart';
import '../models/estado_model.dart';
import '../services/campos_adicionales_api_service.dart';
import '../services/actividades_service.dart';
import '../services/servicios_export_service.dart';
import '../../firmas/pages/firma_captura_screen.dart';
import '../../firmas/controllers/firmas_controller.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import 'package:infoapp/core/enums/modulo_enum.dart';
import '../workflow/estado_workflow_service.dart';
import '../services/servicios_sync_queue.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/main.dart';
import '../widgets/servicios_header.dart';
import '../widgets/servicios_filtros_modal.dart';
import '../servicio_edit_hub.dart';
import '../controllers/branding_controller.dart';

/// ? ENUM NUEVO: Filtro global de 3 estados
enum FiltroEstadoGlobal { todos, activos, finalizados }

/// Página principal que muestra la lista de servicios con WebSocket en tiempo real
class ServiciosListPage extends StatefulWidget {
  const ServiciosListPage({super.key});

  @override
  State<ServiciosListPage> createState() => _ServiciosListPageState();
}

class _ServiciosListPageState extends State<ServiciosListPage> {
  List<ServicioModel> _serviciosFiltrados = [];
  String _filtroTexto = '';
  String? _filtroEstado;
  String? _filtroTipo;
  // ? CAMBIO: Filtro tri-estado (por defecto Activos)
  FiltroEstadoGlobal _filtroGlobal = FiltroEstadoGlobal.activos;
  // Gating de permisos
  bool _sinPermisoListar = false;

  // ThemeProvider para el branding
  final ThemeProvider _themeProvider = ThemeProvider();

  // Listas dinámicas para filtros
  List<String> _tiposDisponibles = [];
  List<String> _estadosDisponibles = [];
  List<String> _columnasVisibles = [];

  // ? NUEVAS VARIABLES: Para campos adicionales
  List<CampoAdicionalModel> _camposAdicionalesUnicos = [];
  bool _isLoadingCampos = false;

  // ? NUEVO: Cache de todos los estados para filtros dinámicos
  List<EstadoModel> _todosLosEstados = [];

  final TextEditingController _searchController = TextEditingController();

  // Controller global (Provider)
  late ServiciosController _controller;

  // ? NUEVAS variables para WebSocket
  Timer? _estadoConexionTimer;
  final bool _mostrandoNotificacionConexion = false;
  DateTime? _ultimaConexion;
  DateTime? _ultimaDesconexion;
  // Preferencias de paginacié³n
  static const String _prefsPageKey = 'servicios_pagina_actual';
  static const String _prefsPageSizeKey = 'tabla_prefs.page_size';

  // ? NUEVO: Conectividad y cola offline
  bool _isConnected = true;
  int _pendingOps = 0;
  StreamSubscription<bool>? _connectivitySub;

  // ? NUEVO: ID de usuario para configuracié³n personalizada
  int? _currentUserId;

  // ? OPTIMIZACIéN: Flag para evitar recargas innecesarias
  bool _datosInicializados = false;

  @override
  void initState() {
    super.initState();
    // ? Inicializar controller global
    _controller = Provider.of<ServiciosController>(context, listen: false);

    _themeProvider.addListener(_onThemeChanged);
    _themeProvider.cargarConfiguracion();

    _controller.addListener(_onControllerChanged);
    _inicializarMonitoreoWebSocket();

    // ? Chequeo puntual de conectividad y conteo inicial de cola offline
    if (kIsWeb) {
      // En web no mostramos banner offline; bloqueamos acciones sin conexié³n.
      if (mounted) setState(() => _isConnected = true);
    } else {
      ConnectivityService.instance.checkNow().then((online) {
        if (!mounted) return;
        setState(() => _isConnected = online);
      });
    }
    _actualizarConteoCola();

    // ? Inicializar permisos desde cache si es necesario y luego cargar datos
    EstadoWorkflowService().ensureLoaded(modulo: ModuloEnum.servicios).then((
      _,
    ) {
      if (mounted) {
        setState(
          () {},
        ); // Refrescar para habilitar botones dependientes del workflow
      }
    });
    _inicializarPermisosYCargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ? CRéTICO: Cuando la página vuelve a ser visible (ej: despué©s de crear servicio desde Inspecciones),
    // aplicar filtros sobre los datos actuales del controller para reflejar cambios
    if (mounted && _controller.servicios.isNotEmpty) {
      _aplicarFiltros();
    }
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    _controller.removeListener(_onControllerChanged);
    // _controller.dispose(); // ? NO eliminar controller global
    _searchController.dispose();

    // ? NUEVO: Limpiar timer de estado
    _estadoConexionTimer?.cancel();
    _connectivitySub?.cancel();

    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    // ? OPTIMIZADO: Cuando el controller cambie, actualizar filtros y notificar
    // No usamos setState aqué­ porque _aplicarFiltros ya lo llama
    _extraerFiltrosDisponibles();
    _aplicarFiltros();

    // ? NUEVO: Detectar cambios en conexié³n WebSocket
    _manejarCambioConexionWebSocket();
  }

  /// ? NUEVO: Inicializar monitoreo de WebSocket
  void _inicializarMonitoreoWebSocket() {
    // Verificar estado de conexié³n cada 30 segundos
    _estadoConexionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _verificarEstadoConexion();
    });
  }

  /// ? NUEVO: Actualizar conteo de operaciones en cola
  Future<void> _actualizarConteoCola() async {
    try {
      final count = await ServiciosSyncQueue.pendingCount();
      if (mounted) setState(() => _pendingOps = count);
    } catch (_) {
      // silencioso
    }
  }

  /// ? NUEVO: Acccié³n manual para sincronizar ahora
  Future<void> _sincronizarAhora() async {
    try {
      final aplicadas = await ServiciosSyncQueue.processPending();
      await _controller.cargarServicios();
      await _actualizarConteoCola();
      if (!mounted) return;
      if (aplicadas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sincronizacié³n realizada: $aplicadas operaciones aplicadas',
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No hay operaciones pendientes por sincronizar',
            ),
            backgroundColor: Colors.grey.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      MyApp.showSnackBar(
        'Error al sincronizar: $e',
        backgroundColor: Colors.red.shade600,
      );
    }
  }

  /// ? NUEVO: Verificar estado de conexié³n perié³dicamente
  void _verificarEstadoConexion() {
    if (!mounted) return;

    final conectado = _controller.webSocketConectado;
    if (!conectado && !_mostrandoNotificacionConexion) {}
  }

  /// ? NUEVO: Manejar cambios de conexié³n WebSocket
  void _manejarCambioConexionWebSocket() {
    if (!mounted) return;

    final conectadoAhora = _controller.webSocketConectado;

    if (conectadoAhora && _ultimaDesconexion != null) {
      // Se reconecté³
      _ultimaConexion = DateTime.now();
      _ultimaDesconexion = null;
    } else if (!conectadoAhora && _ultimaConexion != null) {
      // Se desconecté³
      _ultimaDesconexion = DateTime.now();
    }
  }

  /// ? OPTIMIZADO: Cargar todos los datos en paralelo
  Future<void> _cargarTodosLosDatos({bool forzarRecarga = false}) async {
    // ? OPTIMIZACIéN: Si ya tenemos datos y no es recarga forzada, solo aplicar filtros
    if (_datosInicializados &&
        !forzarRecarga &&
        _controller.servicios.isNotEmpty) {
      _aplicarFiltros();
      return;
    }

    // Gating: bloquear si no tiene permiso de listar servicios
    _sinPermisoListar = !_tienePermisoListarServicios();
    if (_sinPermisoListar) {
      if (mounted) {
        setState(() {
          _serviciosFiltrados = [];
        });
      }
      // Aéºn podemos cargar configuracié³n de columnas desde prefs
      await _cargarConfiguracionColumnas();
      _extraerFiltrosDisponibles();
      return;
    }

    int? savedPage;
    int? savedSize;
    try {
      final prefs = await SharedPreferences.getInstance();

      // ? Obtener userId para configuracié³n de columnas
      final userData = await AuthService.getUserData();
      if (userData != null) {
        _currentUserId = userData['id'];
      }

      final sSize = prefs.getInt(_prefsPageSizeKey);
      if (sSize != null && sSize > 0) {
        savedSize = sSize;
      }
      final sPage = prefs.getInt(_prefsPageKey);
      if (sPage != null && sPage > 0) {
        savedPage = sPage;
      }
    } catch (_) {}

    // ? OPTIMIZACIéN: Cargar servicios UNA SOLA VEZ con los parámetros correctos
    // (evitando llamar a cambiarLimite() y luego irAPagina())
    int limitToUse = savedSize ?? 20;
    int pageToUse = (savedPage != null && savedPage > 1) ? savedPage : 1;

    // Solo cargar, el controller ya maneja el estado interno de lé­mite y página
    // OJO: Si el lé­mite cambié³, hay que actualizarlo en el controller aunque sea "manualmente" o pasarlo al cargar
    if (savedSize != null) {
      _controller.establecerLimiteSinRecargar(savedSize);
    }

    await _controller.cargarServicios(
      pagina: pageToUse,
      limite: limitToUse,
      finalizados: _obtenerValorFiltroFinalizados(),
    );

    // ? PASO 2: Cargar campos adicionales y estados EN PARALELO
    // (ahora que los servicios ya están cargados)
    await Future.wait([
      _cargarCamposAdicionalesUnicos(),
      _cargarEstadosGlobales(),
    ]);

    // ? PASO 3: Aplicar configuracié³n de columnas (ahora los campos ya están cargados)
    await _cargarConfiguracionColumnas();

    _extraerFiltrosDisponibles();
    _aplicarFiltros();

    // ? OPTIMIZACIéN: Marcar datos como inicializados
    if (mounted) {
      setState(() => _datosInicializados = true);
    }
  }

  /// ? NUEVO: Cargar lista global de estados para validaciones dinámicas
  Future<void> _cargarEstadosGlobales() async {
    try {
      final estados = await ServiciosApiService.listarEstados();
      if (mounted) {
        setState(() {
          _todosLosEstados = estados;
        });
      }
    } catch (e) {
      // print('Error cargando estados globales: $e');
    }
  }

  /// Cargar servicios desde el servidor (paginado)
  Future<void> _cargarServicios({int? pagina}) async {
    await _controller.cargarServicios(
      pagina: pagina,
      // Mantenemos filtros server-side
      finalizados: _obtenerValorFiltroFinalizados(),
      buscar: _filtroTexto,
    );
    _extraerFiltrosDisponibles();
    _aplicarFiltros();
  }

  /// ? NUEVO: Cargar todos los campos adicionales éºnicos usando batch
  Future<void> _cargarCamposAdicionalesUnicos() async {
    // ? OPTIMIZACIéN: Si ya tenemos campos cargados, no recargar
    if (_camposAdicionalesUnicos.isNotEmpty) {
      return;
    }

    if (_controller.servicios.isEmpty) {
      //       print('?? No hay servicios cargados, omitiendo carga de campos adicionales');
      return;
    }

    if (mounted) setState(() => _isLoadingCampos = true);

    try {
      //       print('?? Cargando campos adicionales éºnicos (batch) de ${_controller.servicios.length} servicios...');

      // ? NUEVO: Obtener lista de campos que realmente existen en la base de datos
      final camposDisponibles =
          await CamposAdicionalesApiService.obtenerCamposDisponibles(
            modulo: 'Servicios',
          );
      final Set<int> idsValidos = camposDisponibles.map((c) => c.id).toSet();
      //       print('? Campos disponibles en BD: ${idsValidos.length} (IDs: $idsValidos)');

      final serviciosConId =
          _controller.servicios.where((s) => s.id != null).toList();
      final List<int> ids = serviciosConId.map((s) => s.id!).toList();
      final batchResult = await CamposAdicionalesApiService.obtenerCamposBatch(
        servicioIds: ids,
        modulo: 'Servicios',
      );

      // Unificar todos los campos éºnicos
      final Set<int> idsUnicos = {};
      final List<CampoAdicionalModel> camposUnicos = [];
      batchResult.forEach((servicioId, campos) {
        for (final campo in campos) {
          if (!idsUnicos.contains(campo.id)) {
            idsUnicos.add(campo.id);
            camposUnicos.add(campo);
          }
        }
      });

      // ? Filtrar por mé³dulo Servicios/Servicio, modo estricto (sin vacé­o)
      final List<CampoAdicionalModel> camposSoloServicios =
          camposUnicos
              .where(
                (c) => ModuleUtils.esModulo(
                  c.modulo,
                  'Servicios',
                  aceptarVacioComoDestino: false,
                ),
              )
              .toList();

      // ? NUEVO: Filtrar solo campos que existen en la base de datos
      final List<CampoAdicionalModel> camposFiltrados =
          camposSoloServicios.where((c) => idsValidos.contains(c.id)).toList();

      //       print('?? Campos extraé­dos de servicios: ${camposSoloServicios.length}');
      //       print('? Campos válidos (despué©s de filtrar eliminados): ${camposFiltrados.length}');

      // ?? Fallback: si el batch no trae campos, usar metadatos por estado
      List<CampoAdicionalModel> resultadoFinal = camposFiltrados;
      if (resultadoFinal.isEmpty) {
        //         print('?? Fallback de campos adicionales: usando metadatos por estado');
        final estadosUnicos =
            _controller.servicios
                .map((s) => s.estadoId)
                .where((e) => e != null)
                .cast<int>()
                .toSet()
                .toList();
        final List<CampoAdicionalModel> desdeMetadatos = [];
        for (final estadoId in estadosUnicos) {
          try {
            final camposEstado =
                await ServiciosApiService.obtenerCamposPorEstadoRapido(
                  estadoId: estadoId,
                  modulo: 'Servicios',
                );
            desdeMetadatos.addAll(camposEstado);
          } catch (e) {
            //             print('?? Error metadatos estado $estadoId: $e');
          }
        }

        // Unificar por ID y filtrar por mé³dulo Servicios
        final Map<int, CampoAdicionalModel> porId = {};
        for (final c in desdeMetadatos) {
          if (ModuleUtils.esModulo(
                c.modulo,
                'Servicios',
                aceptarVacioComoDestino: false,
              ) &&
              idsValidos.contains(c.id)) {
            // ? Tambié©n filtrar en fallback
            porId[c.id] = c;
          }
        }
        resultadoFinal = porId.values.toList();
      }

      if (mounted) {
        setState(() {
          _camposAdicionalesUnicos = resultadoFinal;
        });
      }

      //       print('? Campos adicionales éºnicos cargados (final): ${_camposAdicionalesUnicos.length}');
      for (final campo in _camposAdicionalesUnicos) {
        //         print('  - ${campo.nombreCampo} (ID: ${campo.id}, Tipo: ${campo.tipoCampo}, Modulo: ${campo.modulo})');
      }
    } catch (e) {
      //       print('? Error cargando campos adicionales éºnicos (batch): $e');
      if (mounted) {
        setState(() {
          _camposAdicionalesUnicos = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingCampos = false);
    }
  }

  /// Extraer filtros disponibles de los servicios cargados
  void _extraerFiltrosDisponibles() {
    _tiposDisponibles = _controller.obtenerTiposUnicos();
    _estadosDisponibles = _controller.obtenerEstadosUnicos();

    //     print('?? Filtros - Tipos: ${_tiposDisponibles.length}, Estados: ${_estadosDisponibles.length}');
  }

  void _buscarServicios(String texto) async {
    if (_sinPermisoListar || !_tienePermisoListarServicios()) {
      if (mounted) {
        setState(() {
          _filtroTexto = texto;
          _serviciosFiltrados = [];
          _sinPermisoListar = true;
        });
      }
      _mostrarBannerPermisos();
      return;
    }

    if (mounted) {
      setState(() {
        _filtroTexto = texto;
      });
    }

    // ? OPTIMIZACIéN: Béºsqueda server-side con paginacié³n normal (20 items)
    // Ya no cargamos 10,000 registros, el servidor filtra y pagina.
    await _controller.cargarServicios(
      pagina: 1,
      buscar: texto,
      // Mantenemos filtros actuales
      finalizados: _obtenerValorFiltroFinalizados(),
    );

    _aplicarFiltros();
  }

  /// ? MéTODO ACTUALIZADO: Refrescar servicios
  Future<void> _refrescarServicios() async {
    //     print('?? Refrescando servicios desde servidor...');

    // Gating: bloquear refresh si no hay permiso
    if (_sinPermisoListar || !_tienePermisoListarServicios()) {
      _sinPermisoListar = true;
      _mostrarBannerPermisos();
      return;
    }

    // ? OPTIMIZACIéN: Resetear flag para forzar recarga completa
    if (mounted) {
      setState(() => _datosInicializados = false);
    }

    await _controller.cargarServicios(
      pagina: _controller.paginaActual,
      finalizados: _obtenerValorFiltroFinalizados(),
      buscar: _filtroTexto,
    );
    _extraerFiltrosDisponibles();
    _aplicarFiltros();

    // ? OPTIMIZACIéN: No recargar campos adicionales en cada refresh
    // Los campos ya se cargaron en _cargarTodosLosDatos() y no cambian frecuentemente
    // await _cargarCamposAdicionalesUnicos();

    // Reconectar WebSocket si está desconectado
    if (!_controller.webSocketConectado) {
      _controller.reconectarWebSocket();
    }

    //     print('? Refresh completado');
  }

  /// ? MéTODO ACTUALIZADO: Crear nuevo servicio
  Future<void> _crearNuevoServicio() async {
    final nuevoServicio = await Navigator.push<ServicioModel>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider(
              create: (_) => ActividadesService(),
              child: const ServicioCreatePage(),
            ),
      ),
    );

    // ? OPTIMIZACIéN: Agregar servicio localmente en lugar de recargar todo
    if (nuevoServicio != null) {
      // ? Actualizacié³n local inmediata usando el objeto completo devuelto por el servidor
      // (el servidor ya aplicé³ triggers y devolvié³ todos los joins)
      _controller.agregarServicioLocal(nuevoServicio);
      _aplicarFiltros();
    }
  }

  /// ? Helper para obtener valor del filtro server-side
  dynamic _obtenerValorFiltroFinalizados() {
    switch (_filtroGlobal) {
      case FiltroEstadoGlobal.finalizados:
        return true;
      case FiltroEstadoGlobal.activos:
        return false;
      case FiltroEstadoGlobal.todos:
      default:
        return 'all';
    }
  }

  void _aplicarFiltros() {
    if (!mounted) return;
    setState(() {
      // Buscar SIEMPRE en todos los servicios cargados
      // El filtrado por estado (Active/Finished) ahora se hace en el servidor
      // por lo que _controller.servicios ya viene pre-filtrado.
      List<ServicioModel> servicios = _controller.buscarServicios(_filtroTexto);

      // Solo aplicamos filtros locales extras si son necesarios (Tipo, Estado especé­fico)
      if (_filtroTipo != null && _filtroTipo!.isNotEmpty) {
        servicios =
            servicios.where((s) => s.tipoMantenimiento == _filtroTipo).toList();
      }

      if (_filtroEstado != null && _filtroEstado!.isNotEmpty) {
        servicios =
            servicios.where((s) => s.estadoNombre == _filtroEstado).toList();
      }

      _serviciosFiltrados = servicios;
    });
  }

  Future<void> _descargarPorFechas(String formato) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecciona rango de fechas',
    );
    if (range == null) return;

    await ServiciosExportService.exportarServiciosPorFechas(
      desde: range.start,
      hasta: range.end,
      formato: formato,
      estado: _filtroEstado,
      tipo: _filtroTipo,
      buscar: _filtroTexto.isNotEmpty ? _filtroTexto : null,
      camposAdicionales: _camposAdicionalesUnicos,
      onSuccess: (m) => _mostrarExito(m),
      onError: (e) => _mostrarError(e),
    );
  }

  /// Modal pequeé±o para centralizar descargas
  Future<void> _mostrarDescargasModal() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Descargar servicios'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Elige una opcié³n:'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.calendar()),
                      label: const Text('Por Fechas'),
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarModalRangoFechasCompacto();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.treeStructure()),
                      label: const Text('Centro de Costo'),
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarModalCentroCosto();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: Icon(
                        PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
                      ),
                      label: const Text('Empresa'),
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarModalEmpresa();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.checkSquareOffset()),
                      label: const Text('Todos (filtrados)'),
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarModalTodo();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  /// Sub-modal: rango de fechas compacto con dos CalendarDatePicker
  Future<void> _mostrarModalRangoFechasCompacto() async {
    DateTime desde = DateTime.now().subtract(const Duration(days: 30));
    DateTime hasta = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Descargar por fechas'),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Desde'),
                              CalendarDatePicker(
                                initialDate: desde,
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                onDateChanged: (d) {
                                  setDialogState(() {
                                    desde = d;
                                    if (hasta.isBefore(desde)) {
                                      hasta = desde;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hasta'),
                              CalendarDatePicker(
                                initialDate: hasta,
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                onDateChanged: (d) {
                                  setDialogState(() {
                                    hasta = d;
                                    if (hasta.isBefore(desde)) {
                                      desde = hasta;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: Icon(PhosphorIcons.fileCsv()),
                          label: const Text('CSV'),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _exportarPorFechasLocal('csv', desde, hasta);
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: Icon(PhosphorIcons.fileXls()),
                          label: const Text('Excel'),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _exportarPorFechasLocal(
                              'excel',
                              desde,
                              hasta,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: Icon(PhosphorIcons.filePdf()),
                          label: const Text('PDF'),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _exportarPorFechasLocal('pdf', desde, hasta);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportarPorFechasLocal(
    String formato,
    DateTime desde,
    DateTime hasta,
  ) async {
    await ServiciosExportService.exportarServiciosPorFechas(
      desde: desde,
      hasta: hasta,
      formato: formato,
      estado: _filtroEstado,
      tipo: _filtroTipo,
      buscar: _filtroTexto.isNotEmpty ? _filtroTexto : null,
      camposAdicionales: _camposAdicionalesUnicos,
      onSuccess: (m) => _mostrarExito(m),
      onError: (e) => _mostrarError(e),
    );
  }

  /// Helper: listar todos con paginacié³n aplicando filtros básicos
  Future<List<ServicioModel>>
  _listarTodosLosServiciosAplicandoFiltrosBasicos() async {
    // Gating: no listar si no hay permiso
    if (_sinPermisoListar || !_tienePermisoListarServicios()) {
      _mostrarBannerPermisos();
      return <ServicioModel>[];
    }
    final servicios = <ServicioModel>[];
    int pagina = 1;

    while (true) {
      final r = await ServiciosApiService.listarServicios(
        pagina: pagina,
        limite: 200,
        buscar: _filtroTexto.isNotEmpty ? _filtroTexto : null,
        estado: _filtroEstado,
        tipo: _filtroTipo,
      );

      // r['servicios'] ya es List<ServicioModel> desde ServiciosApiService
      final serviciosPagina = (r['servicios'] as List<ServicioModel>);
      servicios.addAll(serviciosPagina);

      final tieneSiguiente = (r['tieneSiguiente'] == true);
      final totalPaginas = (r['totalPaginas'] as int?);

      if (!tieneSiguiente || (totalPaginas != null && pagina >= totalPaginas)) {
        break;
      }
      pagina += 1;
    }

    return servicios;
  }

  /// ? Helper: verificar que el campo pertenece al mé³dulo Servicios
  bool _esModuloServicios(String? modulo) {
    final m = (modulo ?? '').trim().toLowerCase();
    // Modo estricto: solo mé³dulos explé­citos de Servicios
    return m == 'servicios' || m == 'servicio';
  }

  /// Sub-modal: Centro de Costo
  Future<void> _mostrarModalCentroCosto() async {
    String centroSeleccionado = '';
    final TextEditingController centroCtrl = TextEditingController();
    // Unificar por minéºsculas para evitar duplicados (INFOAPP == infoapp)
    final Map<String, String> centrosMap = {};
    for (final s in _serviciosFiltrados) {
      final c = s.centroCosto?.trim();
      if (c != null && c.isNotEmpty) {
        final key = c.toLowerCase();
        centrosMap.putIfAbsent(key, () => c);
      }
    }
    final centrosUnicos =
        centrosMap.values.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Descargar por Centro de Costo'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: centroCtrl,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Centro de Costo',
                        hintText: 'Escribe o selecciona',
                      ),
                      onChanged: (v) {
                        setDialogState(() {
                          centroSeleccionado = v.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (centroSeleccionado.isNotEmpty)
                      Text('Seleccionado: $centroSeleccionado'),
                    const SizedBox(height: 8),
                    if (centrosUnicos.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            centrosUnicos.map((c) {
                              final selected =
                                  centroSeleccionado.toLowerCase() ==
                                  c.toLowerCase();
                              return ChoiceChip(
                                label: Text(c),
                                selected: selected,
                                onSelected: (isSelected) {
                                  setDialogState(() {
                                    centroSeleccionado = isSelected ? c : '';
                                    centroCtrl.text = centroSeleccionado;
                                  });
                                },
                              );
                            }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: Icon(PhosphorIcons.fileCsv()),
                  label: const Text('CSV'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _exportarPorCentroCostoLocal(
                      centroSeleccionado,
                      'csv',
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(PhosphorIcons.fileXls()),
                  label: const Text('Excel'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _exportarPorCentroCostoLocal(
                      centroSeleccionado,
                      'excel',
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(PhosphorIcons.filePdf()),
                  label: const Text('PDF'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _exportarPorCentroCostoLocal(
                      centroSeleccionado,
                      'pdf',
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportarPorCentroCostoLocal(
    String centroCosto,
    String formato,
  ) async {
    if (centroCosto.isEmpty) {
      MyApp.showSnackBar('Seleccione un centro de costo');
      return;
    }

    try {
      final todos = await _listarTodosLosServiciosAplicandoFiltrosBasicos();
      final filtrados =
          todos
              .where(
                (s) =>
                    (s.centroCosto?.toLowerCase() ?? '') ==
                    centroCosto.toLowerCase(),
              )
              .toList();

      await ServiciosExportService.exportarServicios(
        servicios: filtrados,
        formato: formato,
        camposAdicionales: _camposAdicionalesUnicos,
        onSuccess: (m) => _mostrarExito(m),
        onError: (e) => _mostrarError(e),
      );
    } catch (e) {
      _mostrarError('Error exportando: $e');
    }
  }

  /// Sub-modal: Empresa
  Future<void> _mostrarModalEmpresa() async {
    String empresaSeleccionada = '';
    final TextEditingController empresaCtrl = TextEditingController();
    // Unificar por minéºsculas para evitar duplicados (INFOAPP == infoapp)
    final Map<String, String> empresasMap = {};
    for (final s in _serviciosFiltrados) {
      final e = s.nombreEmp?.trim();
      if (e != null && e.isNotEmpty) {
        final key = e.toLowerCase();
        empresasMap.putIfAbsent(key, () => e);
      }
    }
    final empresasUnicas =
        empresasMap.values.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Descargar por Empresa'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: empresaCtrl,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Empresa',
                        hintText: 'Escribe o selecciona',
                      ),
                      onChanged: (v) {
                        setDialogState(() {
                          empresaSeleccionada = v.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (empresaSeleccionada.isNotEmpty)
                      Text('Seleccionado: $empresaSeleccionada'),
                    const SizedBox(height: 8),
                    if (empresasUnicas.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            empresasUnicas.map((e) {
                              final selected =
                                  empresaSeleccionada.toLowerCase() ==
                                  e.toLowerCase();
                              return ChoiceChip(
                                label: Text(e),
                                selected: selected,
                                onSelected: (isSelected) {
                                  setDialogState(() {
                                    empresaSeleccionada = isSelected ? e : '';
                                    empresaCtrl.text = empresaSeleccionada;
                                  });
                                },
                              );
                            }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: Icon(PhosphorIcons.fileCsv()),
                  label: const Text('CSV'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _exportarPorEmpresaLocal(empresaSeleccionada, 'csv');
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(PhosphorIcons.fileXls()),
                  label: const Text('Excel'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _exportarPorEmpresaLocal(
                      empresaSeleccionada,
                      'excel',
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(PhosphorIcons.filePdf()),
                  label: const Text('PDF'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _exportarPorEmpresaLocal(empresaSeleccionada, 'pdf');
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportarPorEmpresaLocal(String empresa, String formato) async {
    if (empresa.isEmpty) {
      MyApp.showSnackBar('Seleccione una empresa');
      return;
    }

    try {
      final todos = await _listarTodosLosServiciosAplicandoFiltrosBasicos();
      final filtrados =
          todos
              .where(
                (s) =>
                    (s.nombreEmp?.toLowerCase() ?? '') == empresa.toLowerCase(),
              )
              .toList();

      await ServiciosExportService.exportarServicios(
        servicios: filtrados,
        formato: formato,
        camposAdicionales: _camposAdicionalesUnicos,
        onSuccess: (m) => _mostrarExito(m),
        onError: (e) => _mostrarError(e),
      );
    } catch (e) {
      _mostrarError('Error exportando: $e');
    }
  }

  /// Sub-modal: Todos (filtrados)
  Future<void> _mostrarModalTodo() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Descargar todos (aplicando filtros)'),
          content: const SizedBox(
            width: 420,
            child: Text(
              'Se aplicarán los filtros actuales (texto, estado, tipo).',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: Icon(PhosphorIcons.fileCsv()),
              label: const Text('CSV'),
              onPressed: () async {
                Navigator.pop(context);
                await _exportarTodoFiltrado('csv');
              },
            ),
            ElevatedButton.icon(
              icon: Icon(PhosphorIcons.fileXls()),
              label: const Text('Excel'),
              onPressed: () async {
                Navigator.pop(context);
                await _exportarTodoFiltrado('excel');
              },
            ),
            ElevatedButton.icon(
              icon: Icon(PhosphorIcons.filePdf()),
              label: const Text('PDF'),
              onPressed: () async {
                Navigator.pop(context);
                await _exportarTodoFiltrado('pdf');
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportarTodoFiltrado(String formato) async {
    try {
      final todos = await _listarTodosLosServiciosAplicandoFiltrosBasicos();
      await ServiciosExportService.exportarServicios(
        servicios: todos,
        formato: formato,
        camposAdicionales: _camposAdicionalesUnicos,
        onSuccess: (m) => _mostrarExito(m),
        onError: (e) => _mostrarError(e),
      );
    } catch (e) {
      _mostrarError('Error exportando: $e');
    }
  }

  /// ? OPTIMIZADO: Mostrar detalle (VERSIÓN TRADICIONAL MODERNIZADA)
  Future<void> _mostrarDetalle(ServicioModel servicio) async {
    // ? Regresamos a la página de detalle pero con el resumen UMW integrado
    final servicioActualizado = await Navigator.push<ServicioModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ServicioDetailPage(servicio: servicio),
      ),
    );

    // ? Actualizar localmente si hubo cambios
    if (servicioActualizado != null) {
      _controller.actualizarServicioLocal(servicioActualizado);
      _aplicarFiltros();
      _mostrarExito('Servicio actualizado');
    }
  }

  /// ? NUEVO: Helpers de carga
  void _mostrarCargando(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Expanded(child: Text(mensaje)),
                ],
              ),
            ),
          ),
    );
  }

  void _ocultarCargando() {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  /// ? NUEVO: Abrir pantalla de firma digital (entrega del servicio)
  Future<void> _abrirFirma(ServicioModel servicio) async {
    // 1. Validar si falta la fecha de finalizacié³n
    if (servicio.fechaFinalizacion == null ||
        (servicio.fechaFinalizacion?.trim().isEmpty ?? true)) {
      if (!mounted) return;

      // Calcular fecha mé­nima (Fecha de ingreso)
      DateTime fechaMinima = DateTime.now();
      try {
        if (servicio.fechaIngreso != null) {
          fechaMinima = DateTime.parse(servicio.fechaIngreso!);
        }
      } catch (_) {
        // Fallback a hoy si falla parseo
      }

      // Aseguramos que initialDate >= firstDate
      DateTime fechaInicial = DateTime.now();
      if (fechaInicial.isBefore(fechaMinima)) {
        fechaInicial = fechaMinima;
      }

      // Hack para permitir seleccionar hoy si fechaMinima es mayor que now por horas/minutos
      // Normalizamos fechaMinima al inicio del dé­a
      fechaMinima = DateTime(
        fechaMinima.year,
        fechaMinima.month,
        fechaMinima.day,
      );
      if (fechaInicial.isBefore(fechaMinima)) fechaInicial = fechaMinima;

      // ? UX IMPROVEMENT: Diálogo informativo antes de pedir fecha
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Fecha de Finalizacié³n Requerida'),
              content: const Text(
                'El servicio no tiene registrada una fecha de finalizacié³n.\n\n'
                'Para proceder con la firma y entrega, es necesario registrar cuándo se terminé³ el trabajo. '
                'Por favor seleccione la fecha a continuacié³n.',
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
        firstDate: fechaMinima, // ?? Restriccié³n: No antes de ingreso
        lastDate: DateTime(2100),
        helpText: 'FECHA FINALIZACIéN REQUERIDA',
        cancelText: 'CANCELAR',
        confirmText: 'GUARDAR',
      );

      if (picked == null) return; // Cancelado por usuario

      // 2. Guardar la fecha seleccionada
      _mostrarCargando('Guardando fecha de finalizacié³n...');

      try {
        // Formato YYYY-MM-DD
        final String fechaStr = picked.toIso8601String().split('T')[0];

        // Crear copia actualizada
        final servicioActualizado = servicio.copyWith(
          fechaFinalizacion: fechaStr,
        );

        // Llamar API
        final result = await ServiciosApiService.actualizarServicio(
          servicioActualizado,
        );

        _ocultarCargando(); // Cerrar diálogo de carga

        if (!result.isSuccess) {
          _mostrarError(result.error ?? 'Error al actualizar la fecha');
          return;
        }

        // Actualizar objeto local para pasar a la firma
        servicio = servicioActualizado;
        _mostrarExito('Fecha registrada. Procediendo a firma...');
      } catch (e) {
        _ocultarCargando();
        _mostrarError('Error inesperado: $e');
        return;
      }
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider(
              create: (_) => FirmasController(),
              child: FirmaCapturaScreen(servicio: servicio),
            ),
      ),
    );
    // Opcional: refrescar servicios despué©s de guardar firma
    // await _refrescarServicios();
  }

  /// ? MéTODO ACTUALIZADO: Editar servicio (Redirige a V2)
  Future<void> _editarServicio(ServicioModel servicio) async {
    // ? Navegar al Hub V2 (Unified Maintenance Workspace)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider(
              create: (_) => BrandingController()..cargarBranding(),
              child: ServicioEditHub(servicio: servicio),
            ),
      ),
    );

    // Al volver, siempre recargamos/refrescamos por si hubo cambios
    // El Hub se encarga de notificarlos, pero por seguridad refrescamos la lista
    // localmente si es posible o recargamos.
    _refrescarServicios();
  }

  /// ? MéTODO CORREGIDO: Cargar configuracié³n de columnas guardada
  Future<void> _cargarConfiguracionColumnas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final columnasGuardadas = prefs.getStringList(
        ModuleUtils.prefsKeyColumnasVisibles(
          'Servicios',
          userId: _currentUserId,
        ),
      );

      if (columnasGuardadas != null && columnasGuardadas.isNotEmpty) {
        // ? CORREGIDO: Mantener el orden EXACTO guardado
        final columnasConCampos = <String>[];

        // Recorrer en el orden guardado y validar cada columna
        for (final columna in columnasGuardadas) {
          if (columna.startsWith('campo_')) {
            // Es un campo adicional, verificar que exista
            final campoId = int.tryParse(columna.replaceFirst('campo_', ''));
            if (campoId != null) {
              final existeCampo = _camposAdicionalesUnicos.any(
                (c) => c.id == campoId,
              );
              if (existeCampo) {
                columnasConCampos.add(columna);
              }
            }
          } else {
            // Es una columna estándar, agregarla directamente
            columnasConCampos.add(columna);
          }
        }

        if (mounted) {
          setState(() {
            _columnasVisibles = columnasConCampos;
          });
        }
      } else {
        await _aplicarConfiguracionPorDefecto();
      }
    } catch (e) {
      await _aplicarConfiguracionPorDefecto();
    }
  }

  /// ? NUEVO: Aplicar configuracié³n por defecto
  Future<void> _aplicarConfiguracionPorDefecto() async {
    // Cargar campos adicionales primero
    await _cargarCamposAdicionalesUnicos();

    final configuracionDefecto = [
      'numero',
      'fecha',
      'fecha_finalizacion',
      'orden',
      'tipo',
      'equipo',
      'empresa',
      'estado',
      'acciones',
    ];

    // ? NUEVO: Agregar algunos campos adicionales por defecto (opcional)
    if (_camposAdicionalesUnicos.isNotEmpty) {
      // Agregar los primeros 2 campos adicionales por defecto
      final camposParaDefecto = _camposAdicionalesUnicos.take(2);
      for (final campo in camposParaDefecto) {
        configuracionDefecto.add('campo_${campo.id}');
      }
    }

    if (mounted) {
      setState(() {
        _columnasVisibles = configuracionDefecto;
      });
    }

    //     print('? Configuracié³n por defecto aplicada: ${_columnasVisibles.length} columnas');
  }

  /// ? MéTODO MEJORADO: Guardar configuracié³n con validacié³n
  Future<void> _guardarConfiguracionColumnas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ? Usar clave especé­fica de usuario
      final key = ModuleUtils.prefsKeyColumnasVisibles(
        'Servicios',
        userId: _currentUserId,
      );

      await prefs.setStringList(key, _columnasVisibles);

      //       print('?? Configuracié³n guardada exitosamente:');
      //       print('   - Total columnas: ${_columnasVisibles.length}');
      //       print('   - Columnas: $_columnasVisibles');

      //       print('   - Columnas: $_columnasVisibles');

      // ? NUEVO: Verificar que se guardé³ correctamente
      final verificacion = prefs.getStringList(
        ModuleUtils.prefsKeyColumnasVisibles(
          'Servicios',
          userId: _currentUserId,
        ),
      );
      if (verificacion != null &&
          verificacion.length == _columnasVisibles.length) {
        //         print('? Verificacié³n exitosa: configuracié³n persistida correctamente');
      } else {
        //         print('?? Advertencia: la verificacié³n no coincide');
      }
    } catch (e) {
      //       print('? Error guardando configuracié³n de columnas: $e');
    }
  }

  /// ? Mostrar modal de configuracié³n de columnas
  Future<void> _mostrarConfiguracionColumnas() async {
    // Asegurarse de que los campos esté©n cargados
    if (_camposAdicionalesUnicos.isEmpty && !_isLoadingCampos) {
      await _cargarCamposAdicionalesUnicos();
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder:
          (context) => ModuleColumnConfigModal(
            modulo: 'Servicios',
            userId: _currentUserId, // ? Pasar ID de usuario
            columnasActuales: _columnasVisibles,
            columnasBase: [
              // Obligatorias
              ColumnConfigModel(
                id: 'numero',
                titulo: 'NÂº Servicio',
                descripcion: 'Néºmero éºnico del servicio',
                icono: PhosphorIcons.hash(),
                esObligatoria: true,
                estaVisible: true,
              ),
              ColumnConfigModel(
                id: 'acciones',
                titulo: 'Acciones',
                descripcion: 'Botones de accié³n (ver, editar)',
                icono: PhosphorIcons.dotsThree(),
                esObligatoria: true,
                estaVisible: true,
              ),
              ColumnConfigModel(
                id: 'estado',
                titulo: 'Estado',
                descripcion: 'Estado actual del servicio',
                icono: PhosphorIcons.flag(),
                esObligatoria: true,
                estaVisible: true,
              ),
              ColumnConfigModel(
                id: 'empresa',
                titulo: 'Empresa',
                descripcion: 'Empresa cliente',
                icono: PhosphorIcons.buildings(),
                esObligatoria: true,
                estaVisible: true,
              ),
              ColumnConfigModel(
                id: 'equipo',
                titulo: 'Equipo',
                descripcion: 'Equipo en mantenimiento',
                icono: PhosphorIcons.wrench(),
                esObligatoria: true,
                estaVisible: true,
              ),
              // Configurables
              ColumnConfigModel(
                id: 'fecha',
                titulo: 'Fecha Ingreso',
                descripcion: 'Fecha de ingreso del servicio',
                icono: PhosphorIcons.calendarBlank(),
                estaVisible: _columnasVisibles.contains('fecha'),
              ),
              ColumnConfigModel(
                id: 'fecha_finalizacion',
                titulo: 'Fecha Finalizacié³n',
                descripcion: 'Fecha de finalizacié³n del servicio',
                icono: PhosphorIcons.calendarCheck(),
                estaVisible: _columnasVisibles.contains('fecha_finalizacion'),
              ),
              ColumnConfigModel(
                id: 'actividad',
                titulo: 'Actividad a realizar',
                descripcion: 'Actividad planificada para el servicio',
                icono: Icons.task_alt,
                estaVisible: _columnasVisibles.contains('actividad'),
              ),
              ColumnConfigModel(
                id: 'centro_costo',
                titulo: 'Centro de costo',
                descripcion: 'Centro de costo asociado al servicio',
                icono: Icons.account_balance_wallet,
                estaVisible: _columnasVisibles.contains('centro_costo'),
              ),
              ColumnConfigModel(
                id: 'repuestos',
                titulo: 'Repuestos',
                descripcion: 'Costo total de repuestos asociados',
                icono: Icons.devices_other,
                estaVisible: _columnasVisibles.contains('repuestos'),
              ),
              ColumnConfigModel(
                id: 'orden',
                titulo: 'Orden Cliente',
                descripcion: 'Néºmero de orden del cliente',
                icono: Icons.receipt_long,
                estaVisible: _columnasVisibles.contains('orden'),
              ),
              ColumnConfigModel(
                id: 'tipo',
                titulo: 'Tipo Mantenimiento',
                descripcion: 'Tipo de mantenimiento realizado',
                icono: Icons.build_circle,
                estaVisible: _columnasVisibles.contains('tipo'),
              ),
            ],
            camposAdicionales:
                _camposAdicionalesUnicos
                    .where(
                      (c) => ModuleUtils.esModulo(
                        c.modulo,
                        'Servicios',
                        aceptarVacioComoDestino: false,
                      ),
                    )
                    .toList(),
            onColumnasChanged: (nuevasColumnas) async {
              setState(() => _columnasVisibles = nuevasColumnas);

              // ? NUEVO: Recargar campos adicionales para asegurar sincronizacié³n
              // Esto garantiza que la tabla tenga todos los campos actualizados
              await _cargarCamposAdicionalesUnicos();

              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setStringList(
                  ModuleUtils.prefsKeyColumnasVisibles(
                    'Servicios',
                    userId: _currentUserId,
                  ),
                  nuevasColumnas,
                );
              } catch (_) {}
            },
            aceptarVacioComoModulo: false,
          ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    NetErrorMessages.showMessage(context, mensaje, success: false);
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    NetErrorMessages.showMessage(context, mensaje, success: true);
  }

  /// ? NUEVO: Mostrar notificacié³n de cambios en tiempo real
  void _mostrarNotificacionTiempoReal(String mensaje) {
    MyApp.showSnackBar(mensaje, duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            // AppLogo comentado temporalmente si no existe
            // AppLogo(width: 32, height: 32, backgroundColor: Colors.white.withOpacity(0.9)),
            // SizedBox(width: 12),
            const Expanded(child: Text('Servicios')),
            // ? NUEVO: Indicador de conexié³n WebSocket
            // ? NUEVO: Indicador de conexié³n WebSocket - REMOVIDO
            // _buildIndicadorWebSocket(),
          ],
        ),
        backgroundColor: _themeProvider.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.downloadSimple()),
            tooltip: 'Descargar',
            onPressed:
                PermissionStore.instance.can('Servicios', 'exportar')
                    ? _mostrarDescargasModal
                    : null,
          ),
          IconButton(
            icon: Icon(PhosphorIcons.plus()),
            onPressed:
                PermissionStore.instance.can('Servicios', 'crear')
                    ? _crearNuevoServicio
                    : null,
            tooltip: 'Nuevo Servicio',
          ),
          IconButton(
            icon: Icon(PhosphorIcons.arrowsClockwise()),
            onPressed: _refrescarServicios,
            tooltip: 'Actualizar',
          ),

          // ? BOTéN DE FILTRO MEJORADO (3 ESTADOS) - Con permiso
          if (PermissionStore.instance.can('servicios', 'filtrar'))
            PopupMenuButton<FiltroEstadoGlobal>(
              icon: Icon(
                _filtroGlobal == FiltroEstadoGlobal.activos
                    ? PhosphorIcons.playCircle(
                      PhosphorIconsStyle.fill,
                    ) // ? Fix: Icono sé³lido para Web
                    : _filtroGlobal == FiltroEstadoGlobal.finalizados
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.stack(),
              ),
              tooltip: 'Filtrar por estado global',
              onSelected: (FiltroEstadoGlobal result) async {
                setState(() {
                  _filtroGlobal = result;
                });

                // ? OPTIMIZACIéN: Cargar desde servidor con filtro aplicado
                await _controller.cargarServicios(
                  pagina: 1,
                  finalizados: _obtenerValorFiltroFinalizados(),
                  buscar: _filtroTexto, // Mantener béºsqueda si existe
                );

                _aplicarFiltros();
              },
              itemBuilder:
                  (
                    BuildContext context,
                  ) => <PopupMenuEntry<FiltroEstadoGlobal>>[
                    PopupMenuItem<FiltroEstadoGlobal>(
                      value: FiltroEstadoGlobal.activos,
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.playCircle(),
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          const Text('Solo Activos'),
                        ],
                      ),
                    ),
                    PopupMenuItem<FiltroEstadoGlobal>(
                      value: FiltroEstadoGlobal.finalizados,
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 12),
                          const Text('Solo Finalizados'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<FiltroEstadoGlobal>(
                      value: FiltroEstadoGlobal.todos,
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.stack(),
                            color: Colors.purple.shade700,
                          ),
                          const SizedBox(width: 12),
                          const Text('Mostrar Todos'),
                        ],
                      ),
                    ),
                  ],
            ),

          IconButton(
            icon: Icon(PhosphorIcons.funnel()),
            onPressed: _mostrarFiltros,
            tooltip: 'Filtros',
          ),
          if (kIsWeb &&
              PermissionStore.instance.can('servicios', 'configurar_columnas'))
            IconButton(
              icon: Icon(PhosphorIcons.columns()),
              onPressed: _mostrarConfiguracionColumnas,
              tooltip: 'Configurar Columnas',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderCompacto(),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  /// ? NUEVO: Indicador visual del estado WebSocket en el AppBar
  Widget _buildIndicadorWebSocket() {
    final conectado = _controller.webSocketConectado;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: conectado ? Colors.green : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Gating: UI cuando no hay permiso para listar
    if (_sinPermisoListar || !_tienePermisoListarServicios()) {
      return _buildPermisosInsuficientesEstado();
    }

    if (_controller.isLoading) {
      return _buildLoadingEstado();
    }

    // Mostrar error solo si no hay datos disponibles
    final hasError = _controller.error != null;
    final hasData = _controller.servicios.isNotEmpty;
    if (hasError && !hasData) {
      return _buildErrorEstado(_controller.error!);
    }

    if (_serviciosFiltrados.isEmpty) {
      return _buildEstadoVacio();
    }

    return _buildListaServicios();
  }

  // Helper: verificar permiso de listar servicios
  bool _tienePermisoListarServicios() {
    return PermissionStore.instance.can('servicios', 'listar');
  }

  // UI: estado de permisos insuficientes similar al mé³dulo usuarios
  Widget _buildPermisosInsuficientesEstado() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Sin permisos para listar/ver servicios',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.red.shade600,
            child: const Text(
              'Sin permisos para listar/ver servicios',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ],
    );
  }

  // Mostrar banner de permisos insuficientes
  void _mostrarBannerPermisos() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sin permisos para listar/ver servicios'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildHeaderCompacto() {
    return ServiciosHeader(
      searchController: _searchController,
      filtroTexto: _filtroTexto,
      primaryColor:
          _themeProvider.primaryColor, // ? Pasar color explé­citamente
      onSearch: _buscarServicios,
      onClear: () {
        _searchController.clear();
        _buscarServicios('');
      },
    );
  }

  Widget _buildLoadingEstado() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                _themeProvider.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando servicios...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          // ? NUEVO: Mostrar estado de carga de campos adicionales
          if (_isLoadingCampos) ...[
            const SizedBox(height: 8),
            Text(
              'Cargando campos adicionales...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorEstado(String error) {
    final friendly = NetErrorMessages.from(error, contexto: 'cargar servicios');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Error cargando servicios',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              friendly,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refrescarServicios,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeProvider.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVacio() {
    if (_controller.servicios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay servicios registrados',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Presiona el boté³n + para crear el primer servicio',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No se encontraron servicios',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otros té©rminos de béºsqueda',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Limpiar Filtros'),
              onPressed: () {
                setState(() {
                  _filtroTexto = '';
                  _filtroEstado = null;
                  _filtroTipo = null;
                  _searchController.clear();
                });
                _aplicarFiltros();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _themeProvider.primaryColor,
                side: BorderSide(color: _themeProvider.primaryColor),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// ? MéTODO ACTUALIZADO: Lista de servicios con campos adicionales y paginacié³n
  Widget _buildListaServicios() {
    return Column(
      children: [
        // ? NUEVO: Banner de conectividad y cola offline (solo visible sin conexié³n en mé³vil)
        if (!_isConnected && !kIsWeb)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.red.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pendingOps > 0
                        ? 'Sin conexié³n. Hay $_pendingOps cambios pendientes por sincronizar.'
                        : 'Sin conexié³n. Las operaciones se guardan y se sincronizarán al reconectar.',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refrescarServicios,
            color: _themeProvider.primaryColor,
            child: Column(
              children: [
                Expanded(
                  child: ServiciosTabla(
                    key: ValueKey(
                      Object.hashAll(
                        _serviciosFiltrados.map(
                          (s) =>
                              '${s.id}_${s.estadoNombre}_${s.clienteNombre}_${s.nombreEmp}',
                        ),
                      ),
                    ), // ? CRéTICO: Forzar rebuild cuando cambian datos
                    servicios: _serviciosFiltrados,
                    onServicioTap: (servicio) => _mostrarDetalle(servicio),
                    onEditarServicio: (servicio) => _editarServicio(servicio),
                    onVerDetalle: (servicio) => _mostrarDetalle(servicio),
                    onFirmarServicio: (servicio) => _abrirFirma(servicio),
                    columnasVisibles: _columnasVisibles,
                    camposAdicionales: _camposAdicionalesUnicos,
                    onRefresh: _refrescarServicios,
                    onColumnasReordenadas: (nuevasColumnas) {
                      setState(() {
                        _columnasVisibles = nuevasColumnas;
                      });
                      _guardarConfiguracionColumnas();
                    },
                  ),
                ),
                // Controles de paginacié³n
                _buildPaginacion(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Widget para controles de paginacié³n
  Widget _buildPaginacion() {
    if (_controller.isLoading) return const SizedBox.shrink();
    // Siempre mostrar para permitir cambiar tamaño de página
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _controller.tieneAnterior
                    ? () => _irAPagina(_controller.paginaActual - 1)
                    : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Text(
                'Página ${_controller.paginaActual} de ${_controller.totalPaginas}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Text('Por página:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _controller.limitePorPagina,
                underline: const SizedBox.shrink(),
                items:
                    const [10, 20, 50, 100]
                        .map(
                          (v) => DropdownMenuItem<int>(
                            value: v,
                            child: Text('$v'),
                          ),
                        )
                        .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(_prefsPageSizeKey, v);
                  } catch (_) {}
                  await _controller.cambiarLimite(v);
                  // Al cambiar tamaé±o, empezar desde página 1
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(_prefsPageKey, 1);
                  } catch (_) {}
                  _extraerFiltrosDisponibles();
                  _aplicarFiltros();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _controller.tieneSiguiente
                    ? () => _irAPagina(_controller.paginaActual + 1)
                    : null,
          ),
        ],
      ),
    );
  }

  void _irAPagina(int pagina) async {
    await _cargarServicios(pagina: pagina);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsPageKey, _controller.paginaActual);
    } catch (_) {}
  }

  /// Modal de filtros dinámicos
  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => ServiciosFiltrosModal(
            estadosDisponibles: _estadosDisponibles,
            tiposDisponibles: _tiposDisponibles,
            filtroEstadoActual: _filtroEstado,
            filtroTipoActual: _filtroTipo,
            primaryColor:
                _themeProvider.primaryColor, // ? Pasar color explé­citamente
            onFiltrosChanged: (nuevoEstado, nuevoTipo) {
              if (mounted) {
                setState(() {
                  _filtroEstado = nuevoEstado;
                  _filtroTipo = nuevoTipo;
                });
              }
              _aplicarFiltros();
            },
          ),
    );
  }

  Future<void> _inicializarPermisosYCargar() async {
    // Asegurar que PermissionStore se hidrate desde preferencias antes de gatear
    await PermissionStore.instance.ensureHydratedFromPrefs();
    await _cargarTodosLosDatos();
  }
}
