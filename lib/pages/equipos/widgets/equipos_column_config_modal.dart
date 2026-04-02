import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:infoapp/pages/servicios/models/campo_adicional_model.dart';
import 'package:infoapp/pages/servicios/services/campos_adicionales_api_service.dart';

/// Modal para configurar qué columnas mostrar en la tabla de equipos
class EquiposColumnConfigModal extends StatefulWidget {
  final List<String> columnasActuales;
  final List<CampoAdicionalModel> camposAdicionales;
  final Function(List<String>) onColumnasChanged;

  const EquiposColumnConfigModal({
    super.key,
    required this.columnasActuales,
    required this.camposAdicionales,
    required this.onColumnasChanged,
  });

  @override
  State<EquiposColumnConfigModal> createState() => _EquiposColumnConfigModalState();
}

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

class _EquiposColumnConfigModalState extends State<EquiposColumnConfigModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late List<String> _columnasVisibles;
  late List<ColumnConfigModel> _columnasDisponibles;
  String _busqueda = '';
  final TextEditingController _searchController = TextEditingController();

  // Claves para persistencia (versión Equipos)
  static const String _keyColumnasVisibles = 'equipos_columnas_visibles';
  static const String _keyOrdenColumnas = 'equipos_orden_columnas';

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

    _columnasVisibles = List<String>.from(widget.columnasActuales);
    _inicializarColumnasDisponibles();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _inicializarColumnasDisponibles() {
    // Inicialización de columnas sin logs
    _columnasDisponibles = [
      // Obligatorias
      ColumnConfigModel(
        id: 'numero',
        titulo: 'N° Equipo',
        descripcion: 'Número único del equipo',
        icono: Icons.confirmation_number,
        esObligatoria: true,
        estaVisible: true,
      ),
      ColumnConfigModel(
        id: 'acciones',
        titulo: 'Acciones',
        descripcion: 'Ver y editar equipo',
        icono: Icons.handyman,
        esObligatoria: true,
        estaVisible: true,
      ),

      // Configurables estándar
      ColumnConfigModel(
        id: 'estado',
        titulo: 'Estado',
        descripcion: 'Estado actual del equipo',
        icono: Icons.flag,
        estaVisible: _columnasVisibles.contains('estado'),
      ),
      ColumnConfigModel(
        id: 'empresa',
        titulo: 'Empresa',
        descripcion: 'Empresa propietaria del equipo',
        icono: Icons.business,
        estaVisible: _columnasVisibles.contains('empresa'),
      ),
      ColumnConfigModel(
        id: 'equipo',
        titulo: 'Equipo',
        descripcion: 'Nombre del equipo',
        icono: Icons.precision_manufacturing,
        estaVisible: _columnasVisibles.contains('equipo'),
      ),
      ColumnConfigModel(
        id: 'codigo',
        titulo: 'Código',
        descripcion: 'Código de identificación del equipo',
        icono: Icons.tag,
        estaVisible: _columnasVisibles.contains('codigo'),
      ),
      ColumnConfigModel(
        id: 'marca',
        titulo: 'Marca',
        descripcion: 'Marca del equipo',
        icono: Icons.factory,
        estaVisible: _columnasVisibles.contains('marca'),
      ),
      ColumnConfigModel(
        id: 'modelo',
        titulo: 'Modelo',
        descripcion: 'Modelo del equipo',
        icono: Icons.view_in_ar,
        estaVisible: _columnasVisibles.contains('modelo'),
      ),
      ColumnConfigModel(
        id: 'ciudad',
        titulo: 'Ciudad',
        descripcion: 'Ciudad donde se encuentra el equipo',
        icono: Icons.location_city,
        estaVisible: _columnasVisibles.contains('ciudad'),
      ),
      ColumnConfigModel(
        id: 'placa',
        titulo: 'Placa',
        descripcion: 'Placa o registro del equipo',
        icono: Icons.dns,
        estaVisible: _columnasVisibles.contains('placa'),
      ),
      ColumnConfigModel(
        id: 'planta',
        titulo: 'Planta',
        descripcion: 'Planta o sede del equipo',
        icono: Icons.factory_outlined,
        estaVisible: _columnasVisibles.contains('planta'),
      ),
      ColumnConfigModel(
        id: 'linea',
        titulo: 'Línea',
        descripcion: 'Línea de producción',
        icono: Icons.view_list,
        estaVisible: _columnasVisibles.contains('linea'),
      ),
    ];

    // Agregar campos adicionales dinámicos (filtrados por módulo Equipos)
    final camposEquipos = widget.camposAdicionales
        .where((c) => _esModuloEquipos(c.modulo))
        .toList();
    for (final campo in camposEquipos) {
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
    // Estado final de columnas sin logs
  }

  bool _esModuloEquipos(String? modulo) {
    final m = (modulo ?? '').trim().toLowerCase();
    return m == 'equipos' || m == 'equipo';
  }

  void _toggleColumna(ColumnConfigModel c) {
    if (c.esObligatoria) return;
    setState(() {
      c.estaVisible = !c.estaVisible;
      if (c.estaVisible) {
        if (!_columnasVisibles.contains(c.id)) {
          _columnasVisibles.add(c.id);
        }
      } else {
        _columnasVisibles.remove(c.id);
      }
    });
  }

  Future<void> _guardarConfiguracion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyColumnasVisibles, _columnasVisibles);
      await prefs.setString(
        'equipos_config_columnas',
        jsonEncode({
          'columnas_visibles': _columnasVisibles,
          'fecha_guardado': DateTime.now().toIso8601String(),
          'version': '1.0',
        }),
      );
      widget.onColumnasChanged(_columnasVisibles);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {}
  }

  void _resetear() {
    setState(() {
      _columnasVisibles = [
        'numero',
        'equipo',
        'empresa',
        'estado',
        'acciones',
      ];
      for (final c in _columnasDisponibles) {
        if (c.esObligatoria) {
          c.estaVisible = true;
        } else {
          c.estaVisible = _columnasVisibles.contains(c.id);
        }
      }
    });
  }

  List<ColumnConfigModel> get _filtradas {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return _columnasDisponibles;
    return _columnasDisponibles.where((c) {
      return c.titulo.toLowerCase().contains(q) ||
          c.descripcion.toLowerCase().contains(q);
    }).toList();
  }

  List<ColumnConfigModel> get _obligatorias =>
      _filtradas.where((c) => c.esObligatoria).toList();
  List<ColumnConfigModel> get _estandar =>
      _filtradas.where((c) => !c.esObligatoria && !c.esAdicional).toList();
  List<ColumnConfigModel> get _adicionales =>
      _filtradas.where((c) => c.esAdicional).toList();

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

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar columnas...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _busqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _busqueda = '');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        onChanged: (v) => setState(() => _busqueda = v),
      ),
    );
  }

  Widget _buildColumnsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResumenColumnas(),
          const SizedBox(height: 20),
          if (_obligatorias.isNotEmpty) ...[
            _buildSeccionColumnas(
              'Columnas Obligatorias',
              'Estas columnas siempre estarán visibles',
              _obligatorias,
              Colors.green,
              Icons.lock,
            ),
            const SizedBox(height: 20),
          ],
          if (_estandar.isNotEmpty) ...[
            _buildSeccionColumnas(
              'Columnas Estándar',
              'Columnas básicas del sistema',
              _estandar,
              Colors.blue,
              Icons.table_chart,
            ),
            const SizedBox(height: 20),
          ],
          if (_adicionales.isNotEmpty) ...[
            _buildSeccionColumnas(
              'Campos Adicionales',
              'Campos personalizados configurados',
              _adicionales,
              Colors.purple,
              Icons.extension,
            ),
            const SizedBox(height: 20),
          ],
          if (_filtradas.isEmpty) ...[_buildNoResultsMessage()],
        ],
      ),
    );
  }

  Widget _buildResumenColumnas() {
    final totalVisibles = _columnasDisponibles.where((c) => c.estaVisible).length;
    final totalConfigurables =
        _columnasDisponibles.where((c) => !c.esObligatoria).length;
    final configurablesVisibles =
        _columnasDisponibles.where((c) => !c.esObligatoria && c.estaVisible).length;

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
        ...columnas.map((c) => _buildColumnItem(c)),
      ],
    );
  }

  Widget _buildColumnItem(ColumnConfigModel c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.estaVisible
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
        onTap: () => _toggleColumna(c),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.esAdicional
                      ? CamposAdicionalesApiService.getColorTipoCampo(
                              widget.camposAdicionales
                                  .firstWhere(
                                    (ca) => 'campo_${ca.id}' == c.id,
                                    orElse: () => CampoAdicionalModel(
                                      id: 0,
                                      nombreCampo: '',
                                      tipoCampo: '',
                                      obligatorio: false,
                                      modulo: '',
                                    ),
                                  )
                                  .tipoCampo)
                          .withOpacity(0.1)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  c.icono,
                  color: c.esAdicional
                      ? CamposAdicionalesApiService.getColorTipoCampo(
                          widget.camposAdicionales
                              .firstWhere(
                                (ca) => 'campo_${ca.id}' == c.id,
                                orElse: () => CampoAdicionalModel(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.titulo,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.estaVisible
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (c.esObligatoria)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'OBLIGATORIA',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        if (c.esAdicional)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ADICIONAL',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (c.esObligatoria)
                Icon(Icons.lock, color: Colors.green.shade600, size: 20)
              else
                Switch(
                  value: c.estaVisible,
                  onChanged: (v) => _toggleColumna(c),
                  activeThumbColor: Theme.of(context).primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No se encontraron columnas',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otros términos de búsqueda',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _resetear,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Resetear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade600,
              side: BorderSide(color: Colors.orange.shade600),
            ),
          ),
          const SizedBox(width: 16),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _guardarConfiguracion,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Guardar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTodasLasColumnas(List<ColumnConfigModel> columnas, bool visible) {
    setState(() {
      for (final c in columnas) {
        if (!c.esObligatoria) {
          c.estaVisible = visible;
          if (visible) {
            if (!_columnasVisibles.contains(c.id)) {
              _columnasVisibles.add(c.id);
            }
          } else {
            _columnasVisibles.remove(c.id);
          }
        }
      }
    });
  }
}
