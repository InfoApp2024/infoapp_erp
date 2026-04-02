import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/campo_adicional_model.dart';
import '../services/campos_adicionales_api_service.dart';

/// Modal para configurar qué columnas mostrar en la tabla de servicios
class ColumnConfigModal extends StatefulWidget {
  final List<String> columnasActuales;
  final List<CampoAdicionalModel> camposAdicionales;
  final Function(List<String>) onColumnasChanged;

  const ColumnConfigModal({
    super.key,
    required this.columnasActuales,
    required this.camposAdicionales,
    required this.onColumnasChanged,
  });

  @override
  State<ColumnConfigModal> createState() => _ColumnConfigModalState();
}

/// Modelo para representar una columna configurable
class ColumnConfigModel {
  final String id;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final bool esObligatoria;
  final bool esAdicional;
  bool estaVisible;

  ColumnConfigModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    this.esObligatoria = false,
    this.esAdicional = false,
    this.estaVisible = true,
  });
}

class _ColumnConfigModalState extends State<ColumnConfigModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<ColumnConfigModel> _columnasDisponibles = [];
  List<String> _columnasVisibles = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Claves para persistencia
  static const String _keyColumnasVisibles = 'servicios_columnas_visibles';
  // static const String _keyOrdenColumnas = 'servicios_orden_columnas';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _columnasVisibles = List.from(widget.columnasActuales);
    _initializeColumns();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Inicializar lista de columnas disponibles
  void _initializeColumns() {
    _columnasDisponibles = [
      // ✅ COLUMNAS OBLIGATORIAS (siempre visibles)
      ColumnConfigModel(
        id: 'numero',
        titulo: 'Nº Servicio',
        descripcion: 'Número único del servicio',
        icono: Icons.tag,
        esObligatoria: true,
        estaVisible: true,
      ),
      ColumnConfigModel(
        id: 'acciones',
        titulo: 'Acciones',
        descripcion: 'Botones de acción (ver, editar)',
        icono: Icons.more_horiz,
        esObligatoria: true,
        estaVisible: true,
      ),
      ColumnConfigModel(
        id: 'estado',
        titulo: 'Estado',
        descripcion: 'Estado actual del servicio',
        icono: Icons.flag,
        esObligatoria: true,
        estaVisible: true,
      ),
      ColumnConfigModel(
        id: 'empresa',
        titulo: 'Empresa',
        descripcion: 'Empresa cliente',
        icono: Icons.business,
        esObligatoria: true,
        estaVisible: true,
      ),
      ColumnConfigModel(
        id: 'equipo',
        titulo: 'Equipo',
        descripcion: 'Equipo en mantenimiento',
        icono: Icons.precision_manufacturing,
        esObligatoria: true,
        estaVisible: true,
      ),

      // ✅ COLUMNAS CONFIGURABLES
      ColumnConfigModel(
        id: 'fecha',
        titulo: 'Fecha Ingreso',
        descripcion: 'Fecha de ingreso del servicio',
        icono: Icons.calendar_today,
        estaVisible: _columnasVisibles.contains('fecha'),
      ),
      ColumnConfigModel(
        id: 'fecha_finalizacion',
        titulo: 'Fecha Finalización',
        descripcion: 'Fecha de finalización del servicio',
        icono: Icons.event_available,
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
        descripcion: 'Número de orden del cliente',
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
    ];

    // ✅ AGREGAR CAMPOS ADICIONALES DINÁMICOS (filtrados por módulo Servicios)
    final camposServicios = widget.camposAdicionales
        .where((c) => _esModuloServicios(c.modulo))
        .toList();
    for (final campo in camposServicios) {
      final columnId = 'campo_${campo.id}';
      _columnasDisponibles.add(
        ColumnConfigModel(
          id: columnId,
          titulo: campo.nombreCampo,
          descripcion: 'Campo adicional tipo ${campo.tipoCampo}',
          icono: CamposAdicionalesApiService.getIconoTipoCampo(campo.tipoCampo),
          esAdicional: true,
          estaVisible: _columnasVisibles.contains(columnId),
        ),
      );
    }
  }

  bool _esModuloServicios(String? modulo) {
    final m = (modulo ?? '').trim().toLowerCase();
    return m == 'servicios' || m == 'servicio';
  }

  /// Filtrar columnas según búsqueda
  List<ColumnConfigModel> get _columnasFiltradas {
    if (_searchQuery.isEmpty) {
      return _columnasDisponibles;
    }

    return _columnasDisponibles.where((columna) {
      return columna.titulo.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          columna.descripcion.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
  }

  /// Obtener columnas por categoría
  List<ColumnConfigModel> get _columnasObligatorias {
    return _columnasFiltradas.where((c) => c.esObligatoria).toList();
  }

  List<ColumnConfigModel> get _columnasEstandar {
    return _columnasFiltradas
        .where((c) => !c.esObligatoria && !c.esAdicional)
        .toList();
  }

  List<ColumnConfigModel> get _columnasAdicionales {
    return _columnasFiltradas.where((c) => c.esAdicional).toList();
  }

  /// Cambiar visibilidad de columna
  void _toggleColumnVisibility(ColumnConfigModel columna) {
    if (columna.esObligatoria) return; // No permitir cambiar obligatorias

    setState(() {
      columna.estaVisible = !columna.estaVisible;

      if (columna.estaVisible) {
        if (!_columnasVisibles.contains(columna.id)) {
          _columnasVisibles.add(columna.id);
        }
      } else {
        _columnasVisibles.remove(columna.id);
      }
    });
  }

  /// Guardar configuración en SharedPreferences
  Future<void> _guardarConfiguracion() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar columnas visibles
      await prefs.setStringList(_keyColumnasVisibles, _columnasVisibles);

      // También guardar como JSON para más flexibilidad
      final configJson = jsonEncode({
        'columnas_visibles': _columnasVisibles,
        'fecha_guardado': DateTime.now().toIso8601String(),
        'version': '1.0',
      });

      await prefs.setString('servicios_config_columnas', configJson);

      // Notificar cambio
      widget.onColumnasChanged(_columnasVisibles);

      // Mostrar mensaje de éxito
      _mostrarMensaje('Configuración guardada exitosamente', true);

      // Esperar un momento y cerrar
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _mostrarMensaje('Error guardando configuración', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Resetear a configuración por defecto
  Future<void> _resetearConfiguracion() async {
    final confirmar = await _mostrarDialogoConfirmacion(
      'Resetear Configuración',
      '¿Estás seguro de que quieres resetear la configuración de columnas a los valores por defecto?',
    );

    if (confirmar) {
      setState(() {
        // Configuración por defecto
        _columnasVisibles = [
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

        // Actualizar estado de columnas
        for (final columna in _columnasDisponibles) {
          if (!columna.esObligatoria) {
            columna.estaVisible = _columnasVisibles.contains(columna.id);
          }
        }
      });

      _mostrarMensaje('Configuración reseteada', true);
    }
  }

  /// Mostrar mensaje temporal
  void _mostrarMensaje(String mensaje, bool esExito) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esExito ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esExito ? Colors.green.shade600 : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: esExito ? 2 : 3),
      ),
    );
  }

  /// Mostrar diálogo de confirmación
  Future<bool> _mostrarDialogoConfirmacion(
    String titulo,
    String mensaje,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(titulo),
                content: Text(mensaje),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(child: _buildColumnsList()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// Header del modal
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.view_column, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configurar Columnas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personaliza qué columnas mostrar en la tabla',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Barra de búsqueda
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar columnas...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  /// Lista de columnas organizadas por categorías
  Widget _buildColumnsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de columnas visibles
          _buildResumenColumnas(),
          const SizedBox(height: 20),

          // Columnas obligatorias
          if (_columnasObligatorias.isNotEmpty) ...[
            _buildSeccionColumnas(
              'Columnas Obligatorias',
              'Estas columnas siempre estarán visibles',
              _columnasObligatorias,
              Colors.green,
              Icons.lock,
            ),
            const SizedBox(height: 20),
          ],

          // Columnas estándar
          if (_columnasEstandar.isNotEmpty) ...[
            _buildSeccionColumnas(
              'Columnas Estándar',
              'Columnas básicas del sistema',
              _columnasEstandar,
              Theme.of(context).primaryColor,
              Icons.table_chart,
            ),
            const SizedBox(height: 20),
          ],

          // Campos adicionales
          if (_columnasAdicionales.isNotEmpty) ...[
            _buildSeccionColumnas(
              'Campos Adicionales',
              'Campos personalizados configurados',
              _columnasAdicionales,
              Colors.purple,
              Icons.extension,
            ),
            const SizedBox(height: 20),
          ],

          // Mensaje si no hay resultados
          if (_columnasFiltradas.isEmpty) ...[_buildNoResultsMessage()],
        ],
      ),
    );
  }

  /// Resumen de columnas visibles
  Widget _buildResumenColumnas() {
    final totalVisibles =
        _columnasDisponibles.where((c) => c.estaVisible).length;
    final totalConfigurables =
        _columnasDisponibles.where((c) => !c.esObligatoria).length;
    final configurablesVisibles =
        _columnasDisponibles
            .where((c) => !c.esObligatoria && c.estaVisible)
            .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumen de Configuración',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEstadisticaItem(
                  'Total Visibles',
                  totalVisibles.toString(),
                  Icons.visibility,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEstadisticaItem(
                  'Configurables',
                  '$configurablesVisibles/$totalConfigurables',
                  Icons.tune,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Item de estadística
  Widget _buildEstadisticaItem(
    String label,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Sección de columnas por categoría
  Widget _buildSeccionColumnas(
    String titulo,
    String descripcion,
    List<ColumnConfigModel> columnas,
    Color color,
    IconData icono,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    descripcion,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (columnas.any((c) => !c.esObligatoria)) ...[
              TextButton(
                onPressed: () => _toggleTodasLasColumnas(columnas, true),
                child: const Text('Todas'),
              ),
              TextButton(
                onPressed: () => _toggleTodasLasColumnas(columnas, false),
                child: const Text('Ninguna'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Lista de columnas
        ...columnas.map((columna) => _buildColumnItem(columna)),
      ],
    );
  }

  /// Item individual de columna
  Widget _buildColumnItem(ColumnConfigModel columna) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              columna.estaVisible
                  ? Theme.of(context).primaryColor.withOpacity(0.3)
                  : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _toggleColumnVisibility(columna),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícono de columna
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      columna.esAdicional
                          ? CamposAdicionalesApiService.getColorTipoCampo(
                            widget.camposAdicionales
                                .firstWhere(
                                  (c) => 'campo_${c.id}' == columna.id,
                                  orElse:
                                      () => CampoAdicionalModel(
                                        id: 0,
                                        nombreCampo: '',
                                        tipoCampo: '',
                                        obligatorio: false,
                                        modulo: '',
                                      ),
                                )
                                .tipoCampo,
                          ).withOpacity(0.1)
                          : Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  columna.icono,
                  color:
                      columna.esAdicional
                          ? CamposAdicionalesApiService.getColorTipoCampo(
                            widget.camposAdicionales
                                .firstWhere(
                                  (c) => 'campo_${c.id}' == columna.id,
                                  orElse:
                                      () => CampoAdicionalModel(
                                        id: 0,
                                        nombreCampo: '',
                                        tipoCampo: '',
                                        obligatorio: false,
                                        modulo: '',
                                      ),
                                )
                                .tipoCampo,
                          )
                          : Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),

              const SizedBox(width: 16),

              // Información de columna
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            columna.titulo,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color:
                                  columna.estaVisible
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (columna.esObligatoria)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FIJO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      columna.descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Switch de visibilidad
              if (!columna.esObligatoria)
                Switch.adaptive(
                  value: columna.estaVisible,
                  activeColor: Theme.of(context).primaryColor,
                  onChanged: (value) => _toggleColumnVisibility(columna),
                )
              else
                Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  /// Mensaje de no hay resultados
  Widget _buildNoResultsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No se encontraron columnas',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            Text(
              'Intenta con otros téminos de búsqueda',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  /// Footer con botones de acción
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _resetearConfiguracion,
            icon: const Icon(Icons.refresh),
            label: const Text('Resetear'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading ? null : _guardarConfiguracion,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Guardar Cambios',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
          ),
        ],
      ),
    );
  }

  /// Activar/Desactivar todas las columnas del grupo
  void _toggleTodasLasColumnas(List<ColumnConfigModel> columnas, bool visible) {
    setState(() {
      for (final columna in columnas) {
        if (!columna.esObligatoria) {
          columna.estaVisible = visible;
          if (visible) {
            if (!_columnasVisibles.contains(columna.id)) {
              _columnasVisibles.add(columna.id);
            }
          } else {
            _columnasVisibles.remove(columna.id);
          }
        }
      }
    });
  }
}
