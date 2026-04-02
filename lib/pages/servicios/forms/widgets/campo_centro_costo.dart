import 'package:flutter/material.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';
import '../../services/servicios_api_service.dart';

/// Widget especializado para la selección del centro de costo
class CampoCentroCosto extends StatefulWidget {
  final String? centroSeleccionado;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool canCreate; // ✅ NUEVO
  final bool canDelete; // ✅ NUEVO
  final List<String> centrosDisponibles;

  const CampoCentroCosto({
    super.key,
    required this.centroSeleccionado,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.canCreate = true, // ✅ NUEVO
    this.canDelete = true, // ✅ NUEVO
    this.centrosDisponibles = const [
      'producción',
      'mantenimiento',
      'administración',
    ],
  });

  @override
  State<CampoCentroCosto> createState() => _CampoCentroCostoState();
}

class _CampoCentroCostoState extends State<CampoCentroCosto> {
  List<String> _centros = [];
  final TextEditingController _nuevoCentroController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarCentrosGuardados();
  }

  @override
  void dispose() {
    _nuevoCentroController.dispose();
    super.dispose();
  }

  /// Cargar centros desde la API
  Future<void> _cargarCentrosGuardados() async {
    setState(() => _isLoading = true);

    try {
      final centrosDesdeAPI = await ServiciosApiService.listarCentrosCosto();

      if (mounted) {
        setState(() {
          // Normalizar: trim, lowercase, únicos, ordenados
          _centros =
              centrosDesdeAPI
                  .map((c) => c.trim().toLowerCase())
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort((a, b) => a.compareTo(b));
          _isLoading = false;
        });
      }

      //       print('✅ Centros de costo cargados desde API: $_centros');

      // Si el centro seleccionado no está en la lista, agregarlo
      if (widget.centroSeleccionado != null &&
          !_centros.contains(widget.centroSeleccionado!.trim().toLowerCase())) {
        setState(() {
          _centros.add(widget.centroSeleccionado!.trim().toLowerCase());
          _centros.sort((a, b) => a.compareTo(b));
        });
      }
    } catch (e) {
      //       print('❌ Error cargando centros desde API: $e');
      if (mounted) {
        setState(() {
          _centros = List<String>.from(widget.centrosDisponibles);
          _isLoading = false;
        });
      }
    }
  }

  /// Obtener color según centro de costo
  Color _getColorCentroCosto(String? centro) {
    return Colors.black87;
  }

  /// Obtener icono según centro de costo
  IconData _getIconoCentroCosto(String? centro) {
    switch (centro?.toLowerCase()) {
      case 'producción':
        return Icons.factory;
      case 'mantenimiento':
        return Icons.build_circle;
      case 'administración':
        return Icons.business;
      default:
        return Icons.account_balance;
    }
  }

  /// Obtener descripción según centro
  String _getDescripcionCentro(String centro) {
    switch (centro.toLowerCase()) {
      case 'producción':
        return 'Costos relacionados con producción';
      case 'mantenimiento':
        return 'Costos de mantenimiento y reparación';
      case 'administración':
        return 'Costos administrativos generales';
      default:
        return 'Centro de costo personalizado';
    }
  }

  /// Agregar nuevo centro de costo
  Future<void> _agregarNuevoCentro() async {
    final nuevoCentro = _nuevoCentroController.text.trim().toLowerCase();

    if (nuevoCentro.length < 3) {
      _mostrarError('El centro debe tener al menos 3 caracteres');
      return;
    }

    if (_centros.contains(nuevoCentro)) {
      _mostrarError('Este centro ya existe');
      return;
    }

    setState(() {
      widget.onChanged(nuevoCentro);
      _nuevoCentroController.clear();
    });

    await _cargarCentrosGuardados();
    _mostrarExito('Centro "$nuevoCentro" agregado exitosamente');
  }

  /// Eliminar centro personalizado
  Future<void> _eliminarCentroPersonalizado(String centro) async {
    if (widget.centrosDisponibles.contains(centro)) {
      _mostrarError('No se pueden eliminar los centros predeterminados');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar Centro de Costo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Eliminar el centro "$centro"?'),
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
        _mostrarExito('Eliminando centro...');

        final resultado = await ServiciosApiService.eliminarCentroCosto(centro);

        if (resultado.isSuccess) {
          await _cargarCentrosGuardados();

          if (widget.centroSeleccionado == centro) {
            widget.onChanged(null);
          }

          _mostrarExito(resultado.message ?? 'Centro eliminado exitosamente');
        } else {
          _mostrarError(resultado.error ?? 'Error eliminando centro');
        }
      } catch (e) {
        _mostrarError('Error de conexión: $e');
      }
    }
  }

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
            Text('Cargando centros de costo...'),
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
        initialValue: widget.centroSeleccionado?.trim().toLowerCase(),
        decoration: InputDecoration(
          labelText: 'Centro de Costo',
          prefixIcon: Icon(
            _getIconoCentroCosto(widget.centroSeleccionado),
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
        itemHeight: null, // Permitir altura variable
        isDense: true,
        items: [
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
                  const SizedBox(width: 8),
                  Text(
                    'Agregar nuevo centro',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.canCreate)
            const DropdownMenuItem(
              enabled: false,
              value: null,
              child: Divider(height: 1, thickness: 1),
            ),
          ..._centros.map(
            (centro) => DropdownMenuItem(
              value: centro,
              child: _buildItemCentro(centro),
            ),
          ),
        ],
        selectedItemBuilder: (BuildContext context) {
          return [
            // 1. Item Nuevo
            Text(
              'Agregar nuevo centro',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 2. Separador (no seleccionable, pero requiere placeholder)
            const SizedBox.shrink(),
            // 3. Items de centros
            ..._centros.map((centro) {
              final color = _getColorCentroCosto(centro);
              return Row(
                children: [
                  Text(
                    centro.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }),
          ];
        },
        onChanged: widget.enabled ? _onCentroChanged : null,
        validator: (value) {
          if (widget.validator != null) {
            return widget.validator!(value == '__nuevo__' ? null : value);
          }
          return null;
        },
        menuMaxHeight: 300,
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildItemCentro(String centro) {
    final color = _getColorCentroCosto(centro);
    final brandingColor = Theme.of(context).primaryColor;
    final icono = _getIconoCentroCosto(centro);
    final descripcion = _getDescripcionCentro(centro);
    final esPersonalizado = !widget.centrosDisponibles.contains(centro);

    return Row(
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
            children: [
              Row(
                children: [
                  Text(
                    centro.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
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
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
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
              Text(
                descripcion,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (esPersonalizado && widget.enabled && widget.canDelete)
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 16,
              color: Colors.red.shade400,
            ),
            onPressed: () => _eliminarCentroPersonalizado(centro),
            tooltip: 'Eliminar centro personalizado',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
      ],
    );
  }

  void _onCentroChanged(String? value) {
    if (value == '__nuevo__') {
      _mostrarModalNuevoCentro();
    } else {
      widget.onChanged(value);
    }
  }

  /// Mostrar modal para agregar nuevo centro
  Future<void> _mostrarModalNuevoCentro() async {
    _nuevoCentroController.clear();
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
                    'Nuevo Centro',
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
                      'Ingrese el nombre del nuevo centro de costo para el sistema.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nuevoCentroController,
                      autofocus: true,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Nombre del centro',
                        hintText: 'Ej: VENTAS, OPERACIONES...',
                        prefixIcon: const Icon(Icons.business_center_outlined),
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
                      _agregarNuevoCentro();
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
                  child: const Text('Guardar Centro'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted && widget.centroSeleccionado == null) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownPrincipal(),
      ],
    );
  }
}
