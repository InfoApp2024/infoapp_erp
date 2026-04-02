/// ============================================================================
/// ARCHIVO: servicios_tabla.dart
///
/// PROPéSITO: Widget reutilizable que renderiza la tabla de servicios con
/// funcionalidades avanzadas como:
/// - Vista responsive (tabla en desktop, cards en mé³vil)
/// - Columnas configurables y reordenables con drag & drop
/// - Ordenamiento por columnas
/// - Soporte para campos adicionales dinámicos
/// - Integracié³n con campos personalizados desde la BD
///
/// USO: Se utiliza en ServiciosListPage para mostrar la lista de servicios
/// FUNCIéN: Es el componente visual que muestra los servicios en formato tabla. Maneja toda la lé³gica de presentacié³n,
///  ordenamiento, y configuracié³n de columnas visibles.
/// ============================================================================
///
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
// Para kIsWeb
import '../services/servicios_api_service.dart';
import '../../../../../core/enums/modulo_enum.dart';
import '../workflow/estado_workflow_service.dart'; // ? CORREGIDO: Ruta correcta al servicio de workflow
import '../models/estado_model.dart';
import '../models/servicio_model.dart';
import '../models/campo_adicional_model.dart';
import '../services/campos_adicionales_api_service.dart';
import '../services/servicio_repuestos_api_service.dart';
import '../controllers/servicios_controller.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/download_service.dart';
import 'package:infoapp/core/utils/module_utils.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'notas_modal.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Widget para mostrar servicios en formato tabla responsive con columnas configurables
class ServiciosTabla extends StatefulWidget {
  final List<ServicioModel> servicios;
  final Function(ServicioModel)? onServicioTap;
  final Function(ServicioModel)? onEditarServicio;
  final Function(ServicioModel)? onVerDetalle;
  final Function(ServicioModel)?
  onFirmarServicio; // ? NUEVO: Callback firma digital
  final ScrollController? scrollController;
  final List<String> columnasVisibles;
  final List<CampoAdicionalModel> camposAdicionales;
  final VoidCallback? onRefresh;
  final Function(List<String>)?
  onColumnasReordenadas; // ? NUEVO: Callback para persistencia

  const ServiciosTabla({
    super.key,
    required this.servicios,
    this.onServicioTap,
    this.onEditarServicio,
    this.onVerDetalle,
    this.onFirmarServicio, // ? NUEVO
    this.scrollController,
    this.columnasVisibles = const [],
    this.camposAdicionales = const [],
    this.onRefresh,
    this.onColumnasReordenadas, // ? NUEVO
  });
  @override
  State<ServiciosTabla> createState() => _ServiciosTablaState();
}

/// Modelo para definir columnas configurables
class ColumnModel {
  final String id;
  final String title;
  final double width;
  final bool isNumeric;
  final bool isSortable;
  final bool isRequired; // ? NUEVO: Columnas obligatorias
  final bool isAdditional; // ? NUEVO: Campos adicionales

  ColumnModel({
    required this.id,
    required this.title,
    required this.width,
    this.isNumeric = false,
    this.isSortable = true,
    this.isRequired = false,
    this.isAdditional = false,
  });
}

class _ServiciosTablaState extends State<ServiciosTabla> {
  // Control de ordenamiento
  int _sortColumnIndex = 0;
  bool _sortAscending = false;
  List<ServicioModel> _serviciosOrdenados = [];

  // Controladores de scroll
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  // ? NUEVO: Control de columnas configurables
  List<ColumnModel> _todasLasColumnas = []; // Todas las columnas disponibles
  List<ColumnModel> _columnasVisibles =
      []; // Solo las columnas visibles actualmente
  List<CampoAdicionalModel> _camposAdicionales =
      []; // Campos adicionales dinámicos

  // Estados de carga
  bool _isLoadingConfig = true;

  //: Cache de valores de campos adicionales por servicio
  final Map<int, List<CampoAdicionalModel>> _valoresCamposAdicionales = {};
  bool _isLoadingValoresCampos = false;
  // ? NUEVO: Sistema de cache

  // ? NUEVO: Cache de valores por servicio

  // Cache para columna virtual de repuestos
  final Map<int, double> _costoRepuestosCache = {};
  final Set<int> _costoRepuestosCargando = {};

  // Claves para persistencia

  @override
  void initState() {
    super.initState();
    _initializeData();
  }



  /// ? NUEVO: Tabla con ancho fijo que previene overflow
  Widget _buildFixedWidthTable(double maxWidth) {
    // Calcular ancho mé­nimo necesario
    final anchoMinimo = _columnasVisibles.fold<double>(
      0,
      (sum, col) => sum + col.width,
    );

    // Usar el mayor entre el mé­nimo necesario y el ancho disponible
    final anchoTabla = math.max(anchoMinimo, maxWidth - 24);

    return SizedBox(
      width: anchoTabla,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFixedTableHeader(anchoTabla),
          ..._serviciosOrdenados.asMap().entries.map((entry) {
            final index = entry.key;
            final servicio = entry.value;
            return _buildFixedTableRow(servicio, index, anchoTabla);
          }),
        ],
      ),
    );
  }

  /// ? NUEVO: Header con ancho fijo
  Widget _buildFixedTableHeader(double anchoTabla) {
    final anchosCalculados = _distribuirAnchos(anchoTabla);

    return Container(
      width: anchoTabla,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children:
              _columnasVisibles.asMap().entries.map((entry) {
                final index = entry.key;
                final column = entry.value;
                final ancho = anchosCalculados[index];

                return Container(
                  width: ancho,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: _buildCustomColumnHeader(column, index),
                );
              }).toList(),
        ),
      ),
    );
  }

  /// ? NUEVO: Fila con ancho fijo
  Widget _buildFixedTableRow(
    ServicioModel servicio,
    int index,
    double anchoTabla,
  ) {
    final anchosCalculados = _distribuirAnchos(anchoTabla);

    return Container(
      width: anchoTabla,
      height: 44,
      decoration: BoxDecoration(
        color:
            index % 2 == 0
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children:
              _columnasVisibles.asMap().entries.map((entry) {
                final columnIndex = entry.key;
                final column = entry.value;
                final ancho = anchosCalculados[columnIndex];

                return Container(
                  width: ancho,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: _buildCellContent(column, servicio, ancho),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  /// ? NUEVO: Distribuir anchos de manera proporcional
  List<double> _distribuirAnchos(double anchoTotal) {
    final anchosOriginales = _columnasVisibles.map((col) => col.width).toList();
    final sumaOriginal = anchosOriginales.fold<double>(
      0,
      (sum, ancho) => sum + ancho,
    );

    if (sumaOriginal <= anchoTotal) {
      // Si hay espacio extra, distribuirlo proporcionalmente
      final factor = anchoTotal / sumaOriginal;
      return anchosOriginales.map((ancho) => ancho * factor).toList();
    } else {
      // Si no cabe, escalar proporcionalmente
      final factor = anchoTotal / sumaOriginal;
      return anchosOriginales.map((ancho) => ancho * factor).toList();
    }
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ServiciosTabla oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ? Separar claramente los triggers de actualizacié³n para evitar recálculos innecesarios
    final bool serviciosChanged = widget.servicios != oldWidget.servicios;
    final bool columnasChanged =
        widget.columnasVisibles != oldWidget.columnasVisibles;
    final bool camposChanged =
        widget.camposAdicionales != oldWidget.camposAdicionales;

    if (serviciosChanged) {
      // Solo actualizar la fuente de datos y mantener caches
      _serviciosOrdenados = List.from(widget.servicios);
      _actualizarCacheRepuestosPorCambioDeServicios(
        oldWidget.servicios,
        widget.servicios,
      );
      _actualizarValoresCamposPorCambioDeServicios(
        oldWidget.servicios,
        widget.servicios,
      );
      _ordenarPor(_sortColumnIndex, _sortAscending);
    }

    if (columnasChanged) {
      _columnasGuardadas = widget.columnasVisibles;
      _initializeColumns();
      _aplicarConfiguracionColumnas();
      _ordenarPor(_sortColumnIndex, _sortAscending);
    }

    if (camposChanged) {
      _camposAdicionales = widget.camposAdicionales;
      _initializeColumns();
      _aplicarConfiguracionColumnas();
      if (_camposAdicionales.isNotEmpty) {
        _cargarValoresCamposAdicionales();
      }
      _ordenarPor(_sortColumnIndex, _sortAscending);
    }
  }

  /// ? Actualiza el cache de costo de repuestos segéºn los cambios en la lista de servicios
  void _actualizarCacheRepuestosPorCambioDeServicios(
    List<ServicioModel> anteriores,
    List<ServicioModel> actuales,
  ) {
    final Set<int> idsAnteriores = {
      for (final s in anteriores)
        if (s.id != null) s.id!,
    };
    final Set<int> idsActuales = {
      for (final s in actuales)
        if (s.id != null) s.id!,
    };

    // Eliminar del cache los servicios que ya no están
    for (final id in idsAnteriores.difference(idsActuales)) {
      _costoRepuestosCache.remove(id);
      _costoRepuestosCargando.remove(id);
    }

    // Mantener cache de los que se conservan; no limpiar
    // Para nuevos IDs, no hacer nada aqué­: se calcularán bajo demanda en _buildCeldaRepuestos
  }

  /// ? Nuevo: Mantener cache de valores de campos adicionales ante cambios de servicios
  void _actualizarValoresCamposPorCambioDeServicios(
    List<ServicioModel> anteriores,
    List<ServicioModel> actuales,
  ) {
    // Construir conjuntos de IDs
    final Set<int> idsAnteriores = {
      for (final s in anteriores)
        if (s.id != null) s.id!,
    };
    final Set<int> idsActuales = {
      for (final s in actuales)
        if (s.id != null) s.id!,
    };

    // Remover del mapa de valores los servicios que ya no están visibles
    for (final id in idsAnteriores.difference(idsActuales)) {
      _valoresCamposAdicionales.remove(id);
    }

    // Mantener valores existentes para IDs que permanecen y no disparar una recarga global aqué­.
    // Los nuevos IDs cargarán sus valores cuando se invoque explé­citamente o bajo demanda.
  }

  /// ? ACTUALIZADO: Inicializar datos con carga de valores
  /// ? ACTUALIZADO: Inicializar datos usando parámetros del widget
  Future<void> _initializeData() async {
    setState(() {
      _isLoadingConfig = true;
      _serviciosOrdenados = List.from(widget.servicios);
    });

    try {
      // ? USAR CAMPOS ADICIONALES DEL WIDGET PADRE
      setState(() {
        _camposAdicionales = widget.camposAdicionales;
        _columnasGuardadas = widget.columnasVisibles;
      });

      // Inicializar columnas con los datos recibidos
      _initializeColumns();
      _aplicarConfiguracionColumnas();

      // Cargar valores de campos adicionales si hay campos
      if (_camposAdicionales.isNotEmpty) {
        await _cargarValoresCamposAdicionales();
      }

      _ordenarPor(_sortColumnIndex, _sortAscending);
    } catch (e) {
      // Error inicializando datos
      _initializeColumns();
      _aplicarConfiguracionPorDefecto();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
        });
      }
    }
  }


  List<String> _columnasGuardadas = [];

  // Estado inicial del flujo para condicionar la firma
  EstadoModel? _estadoInicial;

  // Evitar duplicacié³n de initState: cargar estado inicial en didChangeDependencies
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_estadoInicial == null) {
      _cargarEstadoInicial();
    }
  }

  Future<void> _cargarEstadoInicial() async {
    try {
      final estado = await ServiciosApiService.obtenerEstadoInicial();
      if (mounted) {
        setState(() {
          _estadoInicial = estado;
        });
      }
    } catch (_) {
      // Si falla, dejamos _estadoInicial como null y no bloqueamos por estado
    }
  }

  bool _esPrimerEstado(ServicioModel servicio) {
    if (_estadoInicial == null) return false;
    if (servicio.estadoId != null && servicio.estadoId == _estadoInicial!.id) {
      return true;
    }
    if (servicio.estadoNombre != null &&
        servicio.estadoNombre == _estadoInicial!.nombre) {
      return true;
    }
    return false;
  }

  /// ? NUEVO: Configuracié³n por defecto
  List<String> _getConfiguracionPorDefecto() {
    return [
      'numero',
      'fecha',
      'fecha_finalizacion',
      'orden',
      'tipo',
      'actividad',
      'equipo',
      'estado',
      'acciones',
    ];
  }

  /// ? ACTUALIZADO: Inicializar definicié³n de columnas con campos adicionales
  void _initializeColumns() {
    _todasLasColumnas = [
      // ? COLUMNAS OBLIGATORIAS (siempre visibles)
      ColumnModel(
        id: 'numero',
        title: 'NÂº Servicio',
        width: 90,
        isNumeric: true,
        isRequired: true,
      ),
      ColumnModel(
        id: 'acciones',
        title: 'Acciones',
        width: 190, // ? Aumentado para 4 iconos (incluyendo notas)
        isSortable: false,
        isRequired: true,
      ),
      ColumnModel(id: 'estado', title: 'Estado', width: 130, isRequired: true),
      ColumnModel(
        id: 'empresa',
        title: 'Empresa',
        width: 130,
        isRequired: false,
      ),
      ColumnModel(
        id: 'cliente',
        title: 'Cliente',
        width: 140,
        isRequired: true,
      ),
      ColumnModel(id: 'equipo', title: 'Equipo', width: 160, isRequired: true),

      // ? COLUMNAS CONFIGURABLES
      ColumnModel(id: 'fecha', title: 'Fecha Ingreso', width: 110),
      ColumnModel(
        id: 'fecha_finalizacion',
        title: 'Fecha Finalizacié³n',
        width: 110,
      ),

      ColumnModel(
        id: 'actividad',
        title: 'Actividad a realizar',
        width: 180,
        isSortable: false,
      ),
      ColumnModel(id: 'centro_costo', title: 'Centro de costo', width: 140),
      ColumnModel(
        id: 'repuestos',
        title: 'Repuestos',
        width: 110,
        isNumeric: true,
        isSortable: true,
      ),
      ColumnModel(id: 'orden', title: 'Orden Cliente', width: 130),
      ColumnModel(id: 'tipo', title: 'Tipo Mant.', width: 110),
    ];

    // ? AGREGAR CAMPOS ADICIONALES DINéMICOS
    for (final campo in _camposAdicionales) {
      _todasLasColumnas.add(
        ColumnModel(
          id: 'campo_${campo.id}',
          title: campo.nombreCampo,
          width: _getWidthForFieldType(campo.tipoCampo),
          isAdditional: true,
          isSortable: false,
        ),
      );
    }

    // ${_todasLasColumnas.length} columnas totales inicializadas

    // AGREGAR CAMPOS ADICIONALES DINé MICOS
  }

  /// ? NUEVO: Obtener ancho segéºn tipo de campo adicional
  double _getWidthForFieldType(String tipoCampo) {
    switch (tipoCampo.toLowerCase()) {
      case 'booleano':
        return 70; // ? REDUCIDO
      case 'fecha':
      case 'hora':
        return 95; // ? REDUCIDO
      case 'entero':
      case 'decimal':
      case 'moneda':
        return 85; // ? REDUCIDO
      case 'párrafo':
        return 140; // ? REDUCIDO
      case 'archivo':
      case 'imagen':
        return 120; // ? REDUCIDO
      default:
        return 100; // ? REDUCIDO - Texto y otros
    }
  }

  /// ? NUEVO: Aplicar configuracié³n de columnas guardada
  void _aplicarConfiguracionColumnas() {
    if (_columnasGuardadas.isEmpty) {
      _aplicarConfiguracionPorDefecto();
      return;
    }

    // Filtrar columnas visibles segéºn configuracié³n guardada
    final columnasVisibles = <ColumnModel>[];

    // Primero agregar columnas obligatorias (siempre visibles)
    for (final columna in _todasLasColumnas) {
      if (columna.isRequired) {
        columnasVisibles.add(columna);
      }
    }

    // Luego agregar columnas configurables segéºn la configuracié³n guardada
    for (final columnId in _columnasGuardadas) {
      final columna = _todasLasColumnas.firstWhere(
        (c) => c.id == columnId && !c.isRequired,
        orElse: () => ColumnModel(id: '', title: '', width: 0),
      );

      if (columna.id.isNotEmpty) {
        columnasVisibles.add(columna);
      }
    }

    setState(() {
      _columnasVisibles = columnasVisibles;
    });

    // ${_columnasVisibles.length} columnas configuradas como visibles
  }

  /// ? NUEVO: Aplicar configuracié³n por defecto
  void _aplicarConfiguracionPorDefecto() {
    final configuracionDefecto = _getConfiguracionPorDefecto();

    final columnasVisibles = <ColumnModel>[];

    // Agregar columnas obligatorias
    for (final columna in _todasLasColumnas) {
      if (columna.isRequired) {
        columnasVisibles.add(columna);
      }
    }

    // Agregar columnas por defecto
    for (final columnId in configuracionDefecto) {
      final columna = _todasLasColumnas.firstWhere(
        (c) => c.id == columnId && !c.isRequired,
        orElse: () => ColumnModel(id: '', title: '', width: 0),
      );

      if (columna.id.isNotEmpty) {
        columnasVisibles.add(columna);
      }
    }

    // ? CRéTICO: Verificar que el widget esté© montado antes de setState
    if (mounted) {
      setState(() {
        _columnasVisibles = columnasVisibles;
      });
    }
  }

  /// ? OPTIMIZADO: Cargar valores de campos adicionales usando batch para todos los servicios visibles
  Future<void> _cargarValoresCamposAdicionales() async {
    if (widget.servicios.isEmpty || _camposAdicionales.isEmpty) return;

    setState(() {
      _isLoadingValoresCampos = true;
    });

    try {
      // Cargando valores de campos adicionales (batch)
      final serviciosParaCargar = widget.servicios.take(50).toList();
      final ids =
          serviciosParaCargar
              .where((s) => s.id != null)
              .map((s) => s.id!)
              .toList();
      final batchResult = await CamposAdicionalesApiService.obtenerCamposBatch(
        servicioIds: ids,
        modulo: 'Servicios',
      );

      // Llenar el mapa de valores agrupados por servicio
      _valoresCamposAdicionales.clear();
      final idsPermitidos = _camposAdicionales.map((c) => c.id).toSet();
      batchResult.forEach((servicioId, valores) {
        if (valores.isNotEmpty) {
          // ? Filtrar por mé³dulo Servicios y por IDs visibles/configurados
          final filtrados =
              valores
                  .where(
                    (c) =>
                        ModuleUtils.esModulo(
                          c.modulo,
                          'Servicios',
                          aceptarVacioComoDestino: true,
                        ) &&
                        idsPermitidos.contains(c.id),
                  )
                  .toList();

          if (filtrados.isNotEmpty) {
            _valoresCamposAdicionales[servicioId] = filtrados;
          }
        }
      });

      // Valores cargados (batch) para ${_valoresCamposAdicionales.length} servicios

      // ?? Fallback eliminado: No hacer peticiones individuales para evitar N+1
      if (_valoresCamposAdicionales.isEmpty) {
        // print('?? Batch de campos adicionales retorné³ vacé­o.');
      }
    } catch (e) {
      // Error general cargando valores (batch)
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingValoresCampos = false;
        });
      }
    }
  }

  /// ? ACTUALIZADO: Reordenar columnas visibles (TODAS las columnas sin restricciones)
  void _reorderColumns(int oldIndex, int newIndex) {
    setState(() {
      // ? NUEVO: Permitir reordenar TODAS las columnas sin restricciones
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      // Obtener la columna que se está moviendo
      final item = _columnasVisibles.removeAt(oldIndex);

      // Insertarla en la nueva posicié³n
      _columnasVisibles.insert(newIndex, item);

      // Debug para verificar el cambio
      // Columna "${item.title}" movida de posicié³n $oldIndex a $newIndex
      // Nuevo orden: ${_columnasVisibles.map((c) => c.title).toList()}

      // ? Notificar al padre para persistencia
      if (widget.onColumnasReordenadas != null) {
        final nuevosIds = _columnasVisibles.map((c) => c.id).toList();
        widget.onColumnasReordenadas!(nuevosIds);
      }
    });
  }

  /// ? ACTUALIZADO: Ordenar considerando columnas dinámicas
  void _ordenarPor(int columnIndex, bool ascending) {
    if (columnIndex >= _columnasVisibles.length) return;

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      final columnId = _columnasVisibles[columnIndex].id;

      _serviciosOrdenados.sort((a, b) {
        dynamic aValue, bValue;

        // ? MANEJAR CAMPOS ADICIONALES
        if (columnId.startsWith('campo_')) {
          final campoId =
              int.tryParse(columnId.replaceFirst('campo_', '')) ?? 0;

          // Aqué­ necesitaré­as obtener los valores de campos adicionales para cada servicio
          // Por simplicidad, usamos valores por defecto por ahora
          aValue = _getValorCampoAdicional(a, campoId);
          bValue = _getValorCampoAdicional(b, campoId);
        } else {
          // ? CAMPOS ESTéNDAR
          switch (columnId) {
            case 'numero':
              aValue = a.oServicio ?? 0;
              bValue = b.oServicio ?? 0;
              break;
            case 'fecha':
              aValue = a.fechaIngresoDate ?? DateTime.now();
              bValue = b.fechaIngresoDate ?? DateTime.now();
              break;
            case 'orden':
              aValue = a.ordenCliente ?? '';
              bValue = b.ordenCliente ?? '';
              break;
            case 'tipo':
              aValue = a.tipoMantenimiento ?? '';
              bValue = b.tipoMantenimiento ?? '';
              break;
            case 'actividad':
              aValue = a.actividadNombre ?? '';
              bValue = b.actividadNombre ?? '';
              break;
            case 'centro_costo':
              aValue = a.centroCosto ?? '';
              bValue = b.centroCosto ?? '';
              break;
            case 'repuestos':
              aValue = _costoRepuestosCache[a.id ?? -1] ?? 0.0;
              bValue = _costoRepuestosCache[b.id ?? -1] ?? 0.0;
              break;
            case 'equipo':
              aValue = a.equipoNombre ?? '';
              bValue = b.equipoNombre ?? '';
              break;
            case 'empresa':
              aValue = a.nombreEmp ?? '';
              bValue = b.nombreEmp ?? '';
              break;
            case 'estado':
              aValue = a.estadoNombre ?? '';
              bValue = b.estadoNombre ?? '';
              break;
            default:
              aValue = '';
              bValue = '';
          }
        }

        // Comparar valores
        if (aValue is String && bValue is String) {
          return ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        } else if (aValue is int && bValue is int) {
          return ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        } else if (aValue is DateTime && bValue is DateTime) {
          return ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        }

        return 0;
      });
    });
  }

  /// ? ACTUALIZADO: Obtener valor real de campo adicional para un servicio
  String _getValorCampoAdicional(ServicioModel servicio, int campoId) {
    if (servicio.id == null ||
        !_valoresCamposAdicionales.containsKey(servicio.id!)) {
      return ''; // No hay valores cargados para este servicio
    }

    final valoresServicio = _valoresCamposAdicionales[servicio.id!]!;
    final campo = valoresServicio.firstWhere(
      (c) => c.id == campoId,
      orElse:
          () => CampoAdicionalModel(
            id: 0,
            nombreCampo: '',
            tipoCampo: '',
            obligatorio: false,
            modulo: '',
          ),
    );

    if (campo.id == 0 || campo.valor == null) {
      return ''; // Campo no encontrado o sin valor
    }

    // Formatear el valor segéºn el tipo de campo
    return CamposAdicionalesApiService.formatearValorParaTabla(campo);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfig) {
      return _buildLoadingState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildDataTableConScroll();
        } else {
          return _buildCardListConScroll();
        }
      },
    );
  }

  /// ? NUEVO: Estado de carga
  Widget _buildLoadingState() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ? LOADING SPINNER NATIVO PERO PERSONALIZADO
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cargando servicios...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// ? ACTUALIZADO: Tabla con configuracié³n de columnas
  /// ? CORREGIDO: Tabla sin overflow
  Widget _buildDataTableConScroll() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ELIMINADO: _buildTableHeader() (texto "Lista de Servicios")
          // ELIMINADO: _buildColumnToolbar() (texto "Arrastra columnas para reordenar")
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      thickness: 14,
                      radius: const Radius.circular(7),
                      trackVisibility: true,
                      child: Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        thickness: 14,
                        radius: const Radius.circular(7),
                        trackVisibility: true,
                        notificationPredicate:
                            (notification) => notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: _buildFixedWidthTable(constraints.maxWidth),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  /// ? NUEVA: Header de columna personalizado
  Widget _buildCustomColumnHeader(ColumnModel column, int index) {
    return Draggable<int>(
      data: index,
      feedback: Material(
        elevation: 8,
        child: Container(
          width: column.width,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              column.title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        width: column.width,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            column.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) {
          if (details.data != index) {
            _reorderColumns(details.data, index);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovered = candidateData.isNotEmpty;
          return Container(
            width: column.width,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color:
                  isHovered
                      ? Theme.of(context).primaryColor.withOpacity(0.2)
                      : null,
            ),
            child: Row(
              children: [
                // ? NUEVO: Drag handle para TODAS las columnas
                MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Icon(
                    PhosphorIcons.dotsSixVertical(),
                    size: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 4),

                // Té­tulo clickable
                Expanded(
                  child: GestureDetector(
                    onTap:
                        column.isSortable
                            ? () => _ordenarPor(index, !_sortAscending)
                            : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            column.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color:
                                  _sortColumnIndex == index
                                      ? Theme.of(context).colorScheme.primary
                                      : column.isAdditional
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (column.isSortable && _sortColumnIndex == index) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _sortAscending
                                ? PhosphorIcons.arrowUp()
                                : PhosphorIcons.arrowDown(),
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }





  /// ? ACTUALIZADO: Contenido de celda con campos adicionales
  Widget _buildCellContent(
    ColumnModel column,
    ServicioModel servicio, [
    double? anchoDisponible,
  ]) {
    // ? MANEJAR CAMPOS ADICIONALES
    if (column.isAdditional && column.id.startsWith('campo_')) {
      final campoId = int.tryParse(column.id.replaceFirst('campo_', '')) ?? 0;
      final campo = _camposAdicionales.firstWhere(
        (c) => c.id == campoId,
        orElse:
            () => CampoAdicionalModel(
              id: 0,
              nombreCampo: '',
              tipoCampo: '',
              obligatorio: false,
              modulo: '',
            ),
      );

      return Container(
        width: column.width - 8, // ? REDUCIDO PADDING
        alignment: Alignment.centerLeft,
        child: _buildCellContentCampoAdicional(campo, servicio),
      );
    }

    // ? CAMPOS ESTéNDAR con anchos optimizados
    switch (column.id) {
      case 'numero':
        return Container(
          width: (anchoDisponible ?? column.width) - 12,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 3,
            ), // ? REDUCIDO
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
              ),
            ),
            child: Text(
              '#${servicio.oServicio ?? 0}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 10, // ? REDUCIDO
              ),
            ),
          ),
        );

      case 'fecha':
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Text(
            _formatearFecha(servicio.fechaIngreso),
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'fecha_finalizacion':
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Text(
            _formatearFecha(
              servicio.fechaFinalizacion,
            ), // ? Asegéºrate que este campo existe en ServicioModel
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'orden':
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Text(
            servicio.ordenCliente?.toUpperCase() ?? 'SIN ORDEN',
            style: const TextStyle(fontSize: 10), // ? REDUCIDO
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'actividad':
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Text(
            servicio.actividadNombre?.toUpperCase() ?? 'N/A',
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'centro_costo':
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Text(
            servicio.centroCosto?.toUpperCase() ?? 'N/A',
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'repuestos':
        return Container(
          width: column.width - 8,
          alignment: Alignment.center,
          child: _buildCeldaRepuestos(servicio),
        );

      case 'tipo':
        return Container(
          width: column.width - 8,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ), // ? REDUCIDO
            decoration: BoxDecoration(
              color: _getColorTipoMantenimiento(servicio.tipoMantenimiento),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              servicio.tipoMantenimiento?.toUpperCase() ?? 'N/A',
              style: const TextStyle(
                fontSize: 8, // ? REDUCIDO
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

      case 'equipo':
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Text(
            servicio.equipoNombre?.toUpperCase() ?? 'N/A',
            style: const TextStyle(fontSize: 10), // ? REDUCIDO
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'cliente':
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Text(
            (servicio.clienteNombre ?? servicio.nombreEmp ?? 'N/A')
                .toUpperCase(),
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'empresa':
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Text(
            servicio.nombreEmp?.toUpperCase() ?? 'N/A',
            style: const TextStyle(fontSize: 10), // ? REDUCIDO
            overflow: TextOverflow.ellipsis,
          ),
        );

      case 'estado':
        final Color estadoColor =
            servicio.estaAnulado
                ? Theme.of(context).colorScheme.error
                : _parseColor(servicio.estadoColor);
        // Calcular luminancia para elegir texto claro u oscuro
        final double luminance = estadoColor.computeLuminance();
        final Color textoColor =
            luminance > 0.45 ? Colors.black87 : Colors.white;
        return Container(
          width: column.width - 8,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  servicio.estadoNombre?.toUpperCase() ?? 'SIN ESTADO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: textoColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (servicio.estadoComercial != null &&
                  servicio.estadoComercial!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: (servicio.estadoComercial == 'FACTURADO'
                            ? Colors.blue
                            : Colors.green)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: (servicio.estadoComercial == 'FACTURADO'
                              ? Colors.blue
                              : Colors.green)
                          .withOpacity(0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    servicio.estadoComercial!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color:
                          (servicio.estadoComercial == 'FACTURADO'
                              ? Colors.blue.shade700
                              : Colors.green.shade700),
                    ),
                  ),
                ),
              ],
              if (servicio.estaAnulado) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withOpacity(0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'ANULADO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      case 'acciones':
        return Container(
          width: column.width - 8,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(PhosphorIcons.eye(), size: 14), // ? REDUCIDO
                onPressed:
                    PermissionStore.instance.can('Servicios', 'ver')
                        ? () => widget.onVerDetalle?.call(servicio)
                        : null,
                tooltip: 'Ver detalles',
                color: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.all(2), // ? REDUCIDO
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ), // ? REDUCIDO
              ),
              Builder(
                builder: (context) {
                  bool firmaHabilitada = !servicio.estaAnulado;
                  if (firmaHabilitada) {
                    final transiciones = EstadoWorkflowService()
                        .getAvailableTransitions(
                          servicio.estadoNombre ?? '',
                          modulo:
                              ModuloEnum
                                  .servicios, // Importante: especificar mé³dulo
                        );
                    // Solo habilitar si hay alguna transicié³n que requiera firma
                    firmaHabilitada = transiciones.any(
                      (t) => t.triggerCode == 'FIRMA_CLIENTE',
                    );
                  }

                  return IconButton(
                    icon: Icon(PhosphorIcons.signature(), size: 14),
                    onPressed:
                        firmaHabilitada
                            ? () => widget.onFirmarServicio?.call(servicio)
                            : null,
                    tooltip:
                        firmaHabilitada
                            ? 'Firma digital / Entrega'
                            : (servicio.estaAnulado
                                ? 'No disponible: servicio anulado'
                                : 'No requiere firma en este estado'),
                    color: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  );
                },
              ),
              // ? BOTéN NOTAS
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(PhosphorIcons.note(), size: 14),
                      onPressed: () {
                        if (servicio.id != null) {
                          showDialog(
                            context: context,
                            builder:
                                (context) => NotasModal(
                                  idServicio: servicio.id!,
                                  numeroServicio:
                                      servicio.oServicio?.toString() ?? 'N/A',
                                  descripcion:
                                      servicio.actividadNombre ??
                                      'Sin descripcié³n',
                                ),
                          ).then((result) {
                            // ? OPTIMIZACIéN: Solo refrescar si hubo cambios
                            // Y usar refresco segmentado en lugar de recarga total
                            if (result == true && servicio.id != null) {
                              Provider.of<ServiciosController>(
                                context,
                                listen: false,
                              ).refrescarServicioEspecifico(servicio.id!);
                            }
                          });
                        }
                      },
                      tooltip: 'Notas',
                      color: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                    if ((servicio.cantidadNotas ?? 0) > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            '${servicio.cantidadNotas}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  PhosphorIcons.pencilSimple(),
                  size: 14,
                ), // ? REDUCIDO
                onPressed:
                    PermissionStore.instance.can('Servicios', 'actualizar')
                        ? () => widget.onEditarServicio?.call(servicio)
                        : null,
                tooltip: 'Editar',
                color: context.warningColor,
                padding: const EdgeInsets.all(2), // ? REDUCIDO
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ), // ? REDUCIDO
              ),
              // Descarga por servicio movida al detalle para evitar congestié³n
            ],
          ),
        );

      default:
        return SizedBox(
          width: column.width - 8,
          child: const Text(
            'N/A',
            style: TextStyle(fontSize: 10),
          ), // ? REDUCIDO
        );
    }
  }

  /// ? ACTUALIZADO: Contenido de celda para campos adicionales con valores reales
  Widget _buildCellContentCampoAdicional(
    CampoAdicionalModel campo,
    ServicioModel servicio,
  ) {
    // Obtener valor real del servicio
    final valorReal = _getValorCampoAdicional(servicio, campo.id);

    // Si está cargando valores, mostrar indicador
    if (_isLoadingValoresCampos && valorReal.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                color: CamposAdicionalesApiService.getColorTipoCampo(
                  campo.tipoCampo,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Si no hay valor, mostrar vacé­o
    if (valorReal.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CamposAdicionalesApiService.getIconoTipoCampo(campo.tipoCampo),
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '-',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // ? CAMBIO: Renderizar segéºn tipo de campo
    return _buildCellContentPorTipo(campo, servicio, valorReal);
  }


  /// ? ACTUALIZADO: Construir contenido especé­fico por tipo de campo
  Widget _buildCellContentPorTipo(
    CampoAdicionalModel campo,
    ServicioModel servicio,
    String valorReal,
  ) {
    final tipoCampo = campo.tipoCampo.toLowerCase();
    final icono = CamposAdicionalesApiService.getIconoTipoCampo(
      campo.tipoCampo,
    );
    final color = CamposAdicionalesApiService.getColorTipoCampo(
      campo.tipoCampo,
    );

    switch (tipoCampo) {
      case 'texto':
      case 'párrafo':
        return _buildCellTextoConTooltip(icono, color, valorReal, campo);

      case 'link':
        return _buildCellLink(icono, color, valorReal, campo, servicio);

      case 'imagen':
        return _buildCellImagen(icono, color, valorReal, campo, servicio);

      case 'archivo':
        return _buildCellArchivo(icono, color, valorReal, campo, servicio);

      default:
        return _buildCellDefault(icono, color, valorReal);
    }
  }

  /// ? NUEVO: Celda de texto con tooltip para textos largos
  Widget _buildCellTextoConTooltip(
    IconData icono,
    Color color,
    String valorReal,
    CampoAdicionalModel campo,
  ) {
    final valorOriginal = _getValorOriginalCampo(campo);
    final esTextoLargo = valorOriginal.length > 20;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            valorReal.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color:
                  esTextoLargo
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
              decoration: esTextoLargo ? TextDecoration.underline : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (esTextoLargo) ...[
          const SizedBox(width: 2),
          Icon(
            PhosphorIcons.info(),
            size: 10,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child:
          esTextoLargo
              ? Tooltip(
                message: valorOriginal,
                preferBelow: false,
                verticalOffset: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontSize: 12,
                ),
                child: content,
              )
              : content,
    );
  }

  /// ? NUEVO: Celda de imagen con descarga
  Widget _buildCellImagen(
    IconData icono,
    Color color,
    String valorReal,
    CampoAdicionalModel campo,
    ServicioModel servicio,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        onTap: () => _descargarArchivo(campo, servicio, 'imagen'),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  valorReal,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                PhosphorIcons.downloadSimple(),
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ? NUEVO: Celda de archivo con descarga
  Widget _buildCellArchivo(
    IconData icono,
    Color color,
    String valorReal,
    CampoAdicionalModel campo,
    ServicioModel servicio,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        onTap: () => _descargarArchivo(campo, servicio, 'archivo'),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: context.successColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.successColor.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  valorReal,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: context.successColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                PhosphorIcons.downloadSimple(),
                size: 10,
                color: context.successColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ? NUEVO: Celda de link clickeable que abre en nueva pestaé±a
  Widget _buildCellLink(
    IconData icono,
    Color color,
    String valorReal,
    CampoAdicionalModel campo,
    ServicioModel servicio,
  ) {
    // Obtener el valor crudo (URL completa) para el clic
    final String urlCruda = _getValorCampoAdicionalRaw(servicio, campo.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        onTap: () {
          if (urlCruda.isNotEmpty) {
            DownloadService.abrirLinkEnNuevaPestana(urlCruda);
            _mostrarSnackbar(
              '?? Abriendo enlace...',
              Theme.of(context).colorScheme.primary,
            );
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  valorReal,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                PhosphorIcons.arrowSquareOut(),
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ? NUEVO: Obtener valor crudo de campo adicional
  String _getValorCampoAdicionalRaw(ServicioModel servicio, int campoId) {
    if (servicio.id == null ||
        !_valoresCamposAdicionales.containsKey(servicio.id!)) {
      return '';
    }

    final valoresServicio = _valoresCamposAdicionales[servicio.id!]!;
    final campo = valoresServicio.firstWhere(
      (c) => c.id == campoId,
      orElse:
          () => CampoAdicionalModel(
            id: 0,
            nombreCampo: '',
            tipoCampo: '',
            obligatorio: false,
            modulo: '',
          ),
    );

    if (campo.id == 0 || campo.valor == null) {
      return '';
    }
    return campo.valor.toString();
  }

  /// ? NUEVO: Celda por defecto
  Widget _buildCellDefault(IconData icono, Color color, String valorReal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              valorReal,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Columna virtual: Repuestos (costo total)
  Widget _buildCeldaRepuestos(ServicioModel servicio) {
    final servicioId = servicio.id;
    if (servicioId == null) {
      return const Text('N/A', style: TextStyle(fontSize: 10));
    }

    final tieneCosto = _costoRepuestosCache.containsKey(servicioId);
    if (tieneCosto) {
      final costo = _costoRepuestosCache[servicioId] ?? 0.0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.35),
          ),
        ),
        child: Text(
          '\$${costo.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // Si no está en cache y no se está cargando, iniciar carga
    if (!_costoRepuestosCargando.contains(servicioId)) {
      _fetchCostoRepuestos(servicioId);
    }

    return SizedBox(
      height: 14,
      width: 14,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Future<void> _fetchCostoRepuestos(int servicioId) async {
    _costoRepuestosCargando.add(servicioId);
    try {
      final resp = await ServicioRepuestosApiService.listarRepuestosDeServicio(
        servicioId: servicioId,
        incluirDetallesItem: false,
      );
      if (resp.success && resp.data != null) {
        double total = resp.data!.costoTotal;

        // Fallback: si el total viene como 0 pero hay repuestos, calcular localmente
        if (total == 0.0 && resp.data!.repuestos.isNotEmpty) {
          total = resp.data!.repuestos.fold<double>(
            0.0,
            (sum, r) => sum + r.costoTotal,
          );
        }

        // Segundo intento: pedir con detalles si sigue en 0
        if (total == 0.0) {
          try {
            final respDet =
                await ServicioRepuestosApiService.listarRepuestosDeServicio(
                  servicioId: servicioId,
                  incluirDetallesItem: true,
                );
            if (respDet.success && respDet.data != null) {
              total = respDet.data!.costoTotal;
              if (total == 0.0 && respDet.data!.repuestos.isNotEmpty) {
                total = respDet.data!.repuestos.fold<double>(
                  0.0,
                  (sum, r) => sum + r.costoTotal,
                );
              }
            }
          } catch (_) {
            // Ignorar errores en fallback
          }
        }

        _costoRepuestosCache[servicioId] = total;
      } else {
        // Cachear 0 para evitar spinner infinito cuando la respuesta no es exitosa
        _costoRepuestosCache[servicioId] = 0.0;
      }
    } catch (e) {
      // Ignorar errores silenciosamente para celda virtual
      _costoRepuestosCache[servicioId] = 0.0;
    } finally {
      _costoRepuestosCargando.remove(servicioId);
      if (mounted) setState(() {});
    }
  }

  /// ? NUEVO: Obtener valor original (sin formatear) para tooltip
  String _getValorOriginalCampo(CampoAdicionalModel campo) {
    if (campo.valor == null) return '';
    return campo.valor.toString();
  }

  /// ? NUEVO: Funcié³n para descargar archivos
  /// ? MéTODO ACTUALIZADO: Descargar archivo/imagen directamente
  Future<void> _descargarArchivo(
    CampoAdicionalModel campo,
    ServicioModel servicio,
    String tipoArchivo,
  ) async {
    try {
      // Iniciando descarga de $tipoArchivo...
      // Campo ID: ${campo.id}
      // Servicio ID: ${servicio.id}

      // ? PASO 1: Obtener el valor del campo desde el cache
      if (servicio.id == null ||
          !_valoresCamposAdicionales.containsKey(servicio.id!)) {
        _mostrarSnackbar(
          '? No hay datos de campos para este servicio',
          Theme.of(context).colorScheme.error,
        );
        return;
      }

      final valoresServicio = _valoresCamposAdicionales[servicio.id!]!;
      final campoConDatos = valoresServicio.firstWhere(
        (c) => c.id == campo.id,
        orElse:
            () => CampoAdicionalModel(
              id: 0,
              nombreCampo: '',
              tipoCampo: '',
              obligatorio: false,
              modulo: '',
            ),
      );

      // Campo encontrado: ${campoConDatos.id}
      // Valor: ${campoConDatos.valor}

      // ? PASO 2: Validar que el valor sea un Map con datos del archivo
      if (campoConDatos.id == 0 || campoConDatos.valor == null) {
        _mostrarSnackbar(
          '? No hay archivo asociado a este campo',
          Theme.of(context).colorScheme.error,
        );
        return;
      }

      // ? PASO 3: Verificar que sea una estructura válida de archivo
      dynamic datosArchivo = campoConDatos.valor;

      if (datosArchivo is! Map<String, dynamic>) {
        // Si es un string simple, intentar reconstruir la estructura
        if (datosArchivo is String && datosArchivo.isNotEmpty) {
          // Valor es string, reconstruyendo estructura...
          final nombreArchivo = datosArchivo;
          final extension = nombreArchivo.split('.').last.toLowerCase();
          final carpeta = tipoArchivo == 'imagen' ? 'imagenes' : 'archivos';

          datosArchivo = {
            'tipo': tipoArchivo,
            'nombre': nombreArchivo,
            'nombre_original': nombreArchivo,
            'es_existente': true,
            'extension': extension,
            // Construimos solo la ruta péºblica; el servicio arma la URL completa
            'ruta_publica':
                'uploads/campos_adicionales/$carpeta/$nombreArchivo',
          };
        } else {
          _mostrarSnackbar(
            '? Formato de archivo inválido',
            Theme.of(context).colorScheme.error,
          );
          return;
        }
      }

      // Datos del archivo preparados: $datosArchivo

      // ? PASO 4: Usar el servicio de descarga
      _mostrarSnackbar(
        '?? Iniciando descarga...',
        Theme.of(context).colorScheme.primary,
      );

      DownloadService.descargarCampoAdicional(
        datosArchivo: datosArchivo,
        onSuccess: (mensaje) {
          _mostrarSnackbar('? $mensaje', context.successColor);
        },
        onError: (error) {
          _mostrarSnackbar('? $error', Theme.of(context).colorScheme.error);

          // Fallback: Abrir en nueva pestaé±a si falla la descarga
          if (kIsWeb) {
            final rutaPublica =
                (datosArchivo as Map<String, dynamic>)['ruta_publica'] ??
                (datosArchivo)['url_completa'];
            if (rutaPublica != null) {
              DownloadService.abrirArchivoEnNuevaPestana(
                rutaPublica.toString(),
              );
              _mostrarSnackbar(
                '?? Archivo abierto en nueva pestaé±a',
                Theme.of(context).colorScheme.primary,
              );
            }
          }
        },
      );
    } catch (e) {
      // Error al preparar descarga: $e
      _mostrarSnackbar('? Error: $e', Theme.of(context).colorScheme.error);
    }
  }


  /// ? NUEVO: Mostrar snackbar personalizado
  void _mostrarSnackbar(String mensaje, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Cards con scroll para mé³viles (sin cambios mayores)
  Widget _buildCardListConScroll() {
    return Scrollbar(
      thumbVisibility: true,
      interactive: true,
      thickness: 8,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _serviciosOrdenados.length,
        itemBuilder: (context, index) {
          final servicio = _serviciosOrdenados[index];
          return _buildServicioCard(servicio);
        },
      ),
    );
  }

  /// Card para vista mé³vil (sin cambios)
  Widget _buildServicioCard(ServicioModel servicio) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color:
          servicio.estaAnulado
              ? Theme.of(context).colorScheme.error.withOpacity(0.12)
              : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            servicio.estaAnulado
                ? BorderSide(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.35),
                  width: 1,
                )
                : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onServicioTap?.call(servicio),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          servicio.estaAnulado
                              ? Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.12)
                              : Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${servicio.oServicio ?? 0}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            servicio.estaAnulado
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  if (servicio.estaAnulado) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ANULADO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getColorTipoMantenimiento(
                        servicio.tipoMantenimiento,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      servicio.tipoMantenimiento?.toUpperCase() ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCardRow('Cliente:', servicio.ordenCliente ?? 'Sin orden'),
              _buildCardRow('Equipo:', servicio.equipoNombre ?? 'N/A'),
              _buildCardRow('Empresa:', servicio.nombreEmp ?? 'N/A'),
              _buildCardRow('Fecha:', _formatearFecha(servicio.fechaIngreso)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _parseColor(servicio.estadoColor),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      servicio.estadoNombre ?? 'Sin estado',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.eye(), size: 20),
                    onPressed: () => widget.onVerDetalle?.call(servicio),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Builder(
                    builder: (context) {
                      final firmaHabilitada =
                          !servicio.estaAnulado && !_esPrimerEstado(servicio);
                      if (firmaHabilitada) {
                        return IconButton(
                          icon: Icon(PhosphorIcons.signature(), size: 20),
                          onPressed:
                              () => widget.onFirmarServicio?.call(servicio),
                          color: context.successColor,
                          tooltip: 'Firma digital / Entrega',
                        );
                      } else {
                        final tooltipMsg =
                            servicio.estaAnulado
                                ? 'No disponible: servicio anulado'
                                : 'No disponible en estado inicial';
                        return Tooltip(
                          message: tooltipMsg,
                          child: Icon(
                            PhosphorIcons.signature(),
                            size: 20,
                            color: context.successColor.withOpacity(0.4),
                          ),
                        );
                      }
                    },
                  ),
                  // ? BOTéN NOTAS (Mé³vil)
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(PhosphorIcons.notePencil(), size: 20),
                        onPressed: () {
                          if (servicio.id != null) {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => NotasModal(
                                    idServicio: servicio.id!,
                                    numeroServicio:
                                        servicio.oServicio?.toString() ?? 'N/A',
                                    descripcion:
                                        servicio.actividadNombre ??
                                        'Sin descripcié³n',
                                  ),
                            ).then((result) {
                              // ? OPTIMIZACIéN: Solo refrescar si hubo cambios
                              // Y usar refresco segmentado en lugar de recarga total
                              if (result == true && servicio.id != null) {
                                Provider.of<ServiciosController>(
                                  context,
                                  listen: false,
                                ).refrescarServicioEspecifico(servicio.id!);
                              }
                            });
                          }
                        },
                        tooltip: 'Notas',
                        color: Colors.blueGrey,
                      ),
                      if ((servicio.cantidadNotas ?? 0) > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            child: Text(
                              '${servicio.cantidadNotas}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.pencilSimple(), size: 20),
                    onPressed: () => widget.onEditarServicio?.call(servicio),
                    color: context.warningColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Funciones auxiliares (sin cambios)
  String _formatearFecha(String? fecha) {
    if (fecha == null) return 'N/A';
    try {
      final fechaObj = DateTime.parse(fecha);
      return '${fechaObj.day}/${fechaObj.month}/${fechaObj.year}';
    } catch (e) {
      return fecha.length > 10 ? fecha.substring(0, 10) : fecha;
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
}
