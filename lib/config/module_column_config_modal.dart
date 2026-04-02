import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/core/utils/module_utils.dart';
import 'package:infoapp/pages/servicios/models/campo_adicional_model.dart';
import 'package:infoapp/pages/servicios/services/campos_adicionales_api_service.dart';

/// Modelo de columna configurable (genérico por módulo)
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

/// Modal genérico de configuración de columnas por módulo
class ModuleColumnConfigModal extends StatefulWidget {
  final String modulo;
  final List<String> columnasActuales;
  final List<ColumnConfigModel> columnasBase;
  final List<CampoAdicionalModel> camposAdicionales;
  final void Function(List<String>) onColumnasChanged;
  final bool aceptarVacioComoModulo;
  final int? userId; // ✅ NUEVO: Filtro por usuario

  const ModuleColumnConfigModal({
    super.key,
    required this.modulo,
    required this.columnasActuales,
    required this.columnasBase,
    required this.camposAdicionales,
    required this.onColumnasChanged,
    this.aceptarVacioComoModulo = false,
    this.userId,
  });

  @override
  State<ModuleColumnConfigModal> createState() =>
      _ModuleColumnConfigModalState();
}

class _ModuleColumnConfigModalState extends State<ModuleColumnConfigModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<ColumnConfigModel> _columnasDisponibles = [];
  List<String> _columnasVisibles = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<CampoAdicionalModel> _camposAdicionalesActualizados = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _columnasVisibles = List.from(widget.columnasActuales);
    _recargarCamposYInicializar();
    _animationController.forward();
  }

  /// ✅ NUEVO: Recargar campos adicionales desde la API
  Future<void> _recargarCamposYInicializar() async {
    setState(() => _isLoading = true);

    try {
      // Obtener campos adicionales frescos desde la API
      final camposFrescos =
          await CamposAdicionalesApiService.obtenerCamposDisponibles(
            modulo: widget.modulo,
          );

      // Si la API devuelve campos, usarlos; sino usar los del widget
      if (camposFrescos.isNotEmpty) {
        _camposAdicionalesActualizados = camposFrescos;
      } else {
        _camposAdicionalesActualizados = widget.camposAdicionales;
      }
    } catch (e) {
      // En caso de error, usar los campos del widget
      _camposAdicionalesActualizados = widget.camposAdicionales;
    }

    // Inicializar columnas con los campos actualizados
    _initializeColumns();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeColumns() {
    _columnasDisponibles =
        widget.columnasBase
            .map(
              (c) => ColumnConfigModel(
                id: c.id,
                titulo: c.titulo,
                descripcion: c.descripcion,
                icono: c.icono,
                esObligatoria: c.esObligatoria,
                esAdicional: false,
                estaVisible:
                    c.esObligatoria || _columnasVisibles.contains(c.id),
              ),
            )
            .toList();

    // Agregar campos adicionales del módulo destino
    // Seguridad: reforzar filtrado por módulo dentro del modal
    final camposFiltrados =
        _camposAdicionalesActualizados.where((c) {
          return ModuleUtils.esModulo(
            c.modulo,
            widget.modulo,
            aceptarVacioComoDestino: widget.aceptarVacioComoModulo,
          );
        }).toList();

    for (final campo in camposFiltrados) {
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

  List<ColumnConfigModel> get _columnasFiltradas {
    if (_searchQuery.isEmpty) return _columnasDisponibles;
    return _columnasDisponibles.where((c) {
      return c.titulo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.descripcion.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<ColumnConfigModel> get _columnasObligatorias =>
      _columnasFiltradas.where((c) => c.esObligatoria).toList();
  List<ColumnConfigModel> get _columnasEstandar =>
      _columnasFiltradas
          .where((c) => !c.esObligatoria && !c.esAdicional)
          .toList();
  List<ColumnConfigModel> get _columnasAdicionales =>
      _columnasFiltradas.where((c) => c.esAdicional).toList();

  void _toggleColumnVisibility(ColumnConfigModel columna) {
    if (columna.esObligatoria) return;
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

  Future<void> _guardarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ✅ Usar userId si está disponible
      final key = ModuleUtils.prefsKeyColumnasVisibles(
        widget.modulo,
        userId: widget.userId,
      );
      await prefs.setStringList(key, _columnasVisibles);
      widget.onColumnasChanged(_columnasVisibles);
    } catch (e) {
      // Silenciar errores de guardado
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 720,
          height: 560,
          child: Column(
            children: [
              // Encabezado del diálogo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Columnas visibles - ${ModuleUtils.normalizarModulo(widget.modulo)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save, color: Colors.white),
                      tooltip: 'Guardar',
                      onPressed: () async {
                        await _guardarPreferencias();
                        if (mounted) Navigator.of(context).pop();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Buscador
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar columnas...',
                  ),
                ),
              ),
              // Contenido
              Expanded(
                child: ListView(
                  children: [
                    _buildSection('Obligatorias', _columnasObligatorias),
                    _buildSection('Estándar', _columnasEstandar),
                    _buildSection('Adicionales', _columnasAdicionales),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<ColumnConfigModel> columnas) {
    if (columnas.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...columnas.map(_buildRow),
        ],
      ),
    );
  }

  Widget _buildRow(ColumnConfigModel c) {
    return ListTile(
      leading: Icon(c.icono),
      title: Text(c.titulo),
      subtitle: Text(c.descripcion),
      trailing: Switch(
        value: c.estaVisible,
        onChanged: c.esObligatoria ? null : (_) => _toggleColumnVisibility(c),
      ),
    );
  }
}
