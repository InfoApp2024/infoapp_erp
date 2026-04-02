import 'package:flutter/material.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';
import '../../services/servicios_api_service.dart';

/// Widget especializado para la selección del tipo de mantenimiento
class CampoTipoMantenimiento extends StatefulWidget {
  final String? tipoSeleccionado;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool canCreate; // ✅ NUEVO
  final bool canDelete; // ✅ NUEVO
  final List<String> tiposDisponibles;

  const CampoTipoMantenimiento({
    super.key,
    required this.tipoSeleccionado,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.canCreate = true, // ✅ NUEVO
    this.canDelete = true, // ✅ NUEVO
    this.tiposDisponibles = const ['preventivo', 'correctivo', 'predictivo'],
  });

  @override
  State<CampoTipoMantenimiento> createState() => _CampoTipoMantenimientoState();
}

class _CampoTipoMantenimientoState extends State<CampoTipoMantenimiento> {
  List<String> _tipos = [];
  final TextEditingController _nuevoTipoController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarTiposGuardados();
  }

  @override
  void dispose() {
    _nuevoTipoController.dispose();
    super.dispose();
  }

  /// Cargar tipos desde la API
  Future<void> _cargarTiposGuardados() async {
    setState(() => _isLoading = true);

    try {
      // Cargar tipos desde la API
      final tiposDesdeAPI =
          await ServiciosApiService.listarTiposMantenimiento();

      setState(() {
        _tipos = tiposDesdeAPI;
        _isLoading = false;
      });

      //       print('✅ Tipos de mantenimiento cargados desde API: $_tipos');

      // Si el tipo seleccionado no está en la lista, agregarlo (para casos existentes)
      if (widget.tipoSeleccionado != null &&
          !_tipos.contains(widget.tipoSeleccionado!.toLowerCase())) {
        setState(() {
          _tipos.add(widget.tipoSeleccionado!.toLowerCase());
        });
      }
    } catch (e) {
      //       print('❌ Error cargando tipos desde API: $e');
      // Usar tipos por defecto si hay error
      setState(() {
        _tipos = List<String>.from(widget.tiposDisponibles);
        _isLoading = false;
      });
    }
  }

  /// Obtener color según tipo de mantenimiento
  Color _getColorTipoMantenimiento(String? tipo) {
    return Colors.black87;
  }

  /// Obtener icono según tipo de mantenimiento
  IconData _getIconoTipoMantenimiento(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'correctivo':
        return Icons.build;
      case 'preventivo':
        return Icons.schedule;
      case 'predictivo':
        return Icons.analytics;
      default:
        return Icons.settings;
    }
  }

  /// Obtener descripción según tipo de mantenimiento
  String _getDescripcionTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'correctivo':
        return 'Reparación de fallas existentes';
      case 'preventivo':
        return 'Mantenimiento programado regular';
      case 'predictivo':
        return 'Basado en análisis y predicciones';
      default:
        return 'Tipo personalizado de mantenimiento';
    }
  }

  /// Agregar nuevo tipo de mantenimiento
  Future<void> _agregarNuevoTipo() async {
    final nuevoTipo = _nuevoTipoController.text.trim().toLowerCase();

    if (nuevoTipo.length < 3) {
      _mostrarError('El tipo debe tener al menos 3 caracteres');
      return;
    }

    if (_tipos.contains(nuevoTipo)) {
      _mostrarError('Este tipo ya existe');
      return;
    }
    try {
      setState(() => _isLoading = true);

      // Crear el tipo en la API para que el backend lo reconozca
      final resultado = await ServiciosApiService.crearTipoMantenimiento(
        nuevoTipo,
      );

      if (resultado.isSuccess) {
        // Seleccionar el nuevo tipo y cerrar el campo
        setState(() {
          widget.onChanged(nuevoTipo);
          _nuevoTipoController.clear();
        });

        // Recargar tipos desde la API para incluir el nuevo
        await _cargarTiposGuardados();

        _mostrarExito(
          resultado.message ?? 'Tipo "$nuevoTipo" agregado exitosamente',
        );
      } else {
        _mostrarError(
          resultado.error ?? 'No se pudo crear el nuevo tipo en el servidor',
        );
      }
    } catch (e) {
      _mostrarError('Error creando el nuevo tipo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Eliminar tipo personalizado de la base de datos
  Future<void> _eliminarTipoPersonalizado(String tipo) async {
    // Solo permitir eliminar tipos no predeterminados
    if (widget.tiposDisponibles.contains(tipo)) {
      _mostrarError('No se pueden eliminar los tipos predeterminados');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar Tipo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Eliminar el tipo "$tipo"?'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Solo se puede eliminar si no está siendo usado por ningún servicio.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                          ),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      try {
        // Mostrar indicador de carga
        _mostrarExito('Eliminando tipo...');

        // Llamar a la API para eliminar
        final resultado = await ServiciosApiService.eliminarTipoMantenimiento(
          tipo,
        );

        if (resultado.isSuccess) {
          // Recargar tipos desde la API
          await _cargarTiposGuardados();

          // Si era el tipo seleccionado, deseleccionar
          if (widget.tipoSeleccionado == tipo) {
            widget.onChanged(null);
          }

          _mostrarExito(resultado.message ?? 'Tipo eliminado exitosamente');
        } else {
          _mostrarError(resultado.error ?? 'Error eliminando tipo');
        }
      } catch (e) {
        _mostrarError('Error de conexión: $e');
      }
    }
  }

  /// Mostrar mensaje de error
  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Mostrar mensaje de éxito
  void _mostrarExito(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Construir dropdown principal
  Widget _buildDropdownPrincipal() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Cargando tipos de mantenimiento...'),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: widget.tipoSeleccionado?.toLowerCase(),
        decoration: InputDecoration(
          labelText: 'Tipo de Mantenimiento',
          prefixIcon: Icon(
            _getIconoTipoMantenimiento(widget.tipoSeleccionado),
            // Usar color de branding configurado
            color: Theme.of(context).primaryColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        isExpanded: true,
        selectedItemBuilder: (context) {
          return [
            // __nuevo__
            Text(
              'Agregar nuevo tipo',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Divider (null)
            const SizedBox.shrink(),
            // Tipos
            ..._tipos.map((tipo) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tipo.toUpperCase(),
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }),
          ];
        },
        items: [
          // AJUSTE: Opción para agregar nuevo al principio (Condicional)
          if (widget.canCreate)
            DropdownMenuItem(
              value: '__nuevo__',
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Agregar nuevo tipo',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          // Divisor visual
          if (widget.canCreate)
            const DropdownMenuItem(
              enabled: false,
              value: null,
              child: Divider(height: 1, thickness: 1),
            ),
          // Tipos existentes
          ..._tipos.map(
            (tipo) =>
                DropdownMenuItem(value: tipo, child: _buildItemTipo(tipo)),
          ),
        ],
        onChanged: widget.enabled ? _onTipoChanged : null,
        validator: (value) {
          if (widget.validator != null) {
            return widget.validator!(value == '__nuevo__' ? null : value);
          }
          return null;
        },
        menuMaxHeight: 300,
        dropdownColor: Colors.white,
        isDense: true, // Permite altura variable en items
        itemHeight: null, // Permite que los items se ajusten al contenido
      ),
    );
  }

  /// Construir item del tipo en dropdown
  Widget _buildItemTipo(String tipo) {
    final color = _getColorTipoMantenimiento(tipo);
    final brandingColor = Theme.of(context).primaryColor;
    final icono = _getIconoTipoMantenimiento(tipo);
    final descripcion = _getDescripcionTipo(tipo);
    final esPersonalizado = !widget.tiposDisponibles.contains(tipo);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: brandingColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icono, size: 16, color: brandingColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tipo.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (esPersonalizado) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PERSONALIZADO',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Botón de eliminar para tipos personalizados
          if (esPersonalizado && widget.enabled && widget.canDelete)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.red.shade400,
              ),
              onPressed: () => _eliminarTipoPersonalizado(tipo),
              tooltip: 'Eliminar tipo personalizado',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  /// Manejar cambio de tipo
  void _onTipoChanged(String? value) {
    if (value == '__nuevo__') {
      _mostrarModalNuevoTipo();
    } else {
      widget.onChanged(value);
    }
  }

  /// Mostrar modal para agregar nuevo tipo
  Future<void> _mostrarModalNuevoTipo() async {
    _nuevoTipoController.clear();
    final formKey = GlobalKey<FormState>();

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_circle,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Nuevo Tipo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ingrese el nombre del nuevo tipo de mantenimiento para el sistema.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nuevoTipoController,
                      autofocus: true,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Nombre del tipo',
                        hintText: 'Ej: EMERGENCIA, RUTINARIO...',
                        prefixIcon: const Icon(Icons.label_important_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 3) {
                          return 'Mínimo 3 caracteres';
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
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context);
                      _agregarNuevoTipo();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Guardar Tipo'),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Al cerrar el modal, si no se guardó nada, resetear la selección visual si es necesario
    if (mounted && widget.tipoSeleccionado == null) {
      setState(() {
        // Forzar reconstrucción para limpiar el dropdown si se canceló
      });
    }
  }

  /// Construir información del tipo seleccionado
  Widget _buildInformacionTipoSeleccionado() {
    if (widget.tipoSeleccionado == null) {
      return const SizedBox.shrink();
    }

    final color = _getColorTipoMantenimiento(widget.tipoSeleccionado);
    final icono = _getIconoTipoMantenimiento(widget.tipoSeleccionado);
    final descripcion = _getDescripcionTipo(widget.tipoSeleccionado!);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tipoSeleccionado!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown principal
        _buildDropdownPrincipal(),
      ],
    );
  }
}
