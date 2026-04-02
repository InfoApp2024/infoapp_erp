import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';
import '../widgets/color_picker_widget.dart';

/// Modal para editar un estado existente
class EditStateDialog extends StatefulWidget {
  final Map<String, dynamic> estado;
  final List<Map<String, dynamic>> estadosBase;
  final Function(int id, Map<String, dynamic>) onUpdate;
  final bool isProtected;
  final String modulo;

  const EditStateDialog({
    super.key,
    required this.estado,
    required this.estadosBase,
    required this.onUpdate,
    required this.modulo,
    this.isProtected = false,
  });

  @override
  State<EditStateDialog> createState() => _EditStateDialogState();
}

class _EditStateDialogState extends State<EditStateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _ordenController;

  late String _colorSeleccionado;
  late String? _estadoBaseSeleccionado;
  late bool _bloqueaCierre;
  late bool _esFinal;

  @override
  void initState() {
    super.initState();

    // Inicializar con valores del estado actual
    _nombreController = TextEditingController(
      text: widget.estado['nombre_estado'] ?? '',
    );
    _ordenController = TextEditingController(
      text: widget.estado['orden']?.toString() ?? '0',
    );
    _colorSeleccionado = widget.estado['color'] ?? '#2196F3';
    _estadoBaseSeleccionado = widget.estado['estado_base_codigo'];
    _bloqueaCierre =
        (int.tryParse(widget.estado['bloquea_cierre']?.toString() ?? '0') ??
            0) ==
        1;
    _esFinal =
        (int.tryParse(widget.estado['es_final']?.toString() ?? '0') ?? 0) == 1;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _ordenController.dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (!_formKey.currentState!.validate()) return;

    final id = int.tryParse(widget.estado['id'].toString());
    if (id == null) return;

    final data = {
      'nombre_estado': _nombreController.text.trim(),
      'color': _colorSeleccionado,
      'codigo_base': _estadoBaseSeleccionado,
      'bloquea_cierre': _bloqueaCierre ? 1 : 0,
      'es_final': _esFinal ? 1 : 0,
      'orden': int.tryParse(_ordenController.text) ?? 0,
    };

    widget.onUpdate(id, data);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WorkflowDesignConstants.radiusLg),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: WorkflowTheme.dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
              decoration: BoxDecoration(
                gradient: WorkflowTheme.purpleGradient(),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(WorkflowDesignConstants.radiusLg),
                  topRight: Radius.circular(WorkflowDesignConstants.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: WorkflowDesignConstants.iconLg,
                  ),
                  const SizedBox(width: WorkflowDesignConstants.spacingMd),
                  const Expanded(
                    child: Text(
                      'Editar Estado',
                      style: TextStyle(
                        fontSize: WorkflowDesignConstants.title,
                        fontWeight: WorkflowDesignConstants.fontBold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Contenido
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(
                  WorkflowDesignConstants.spacingLg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre
                      Text(
                        'Nombre del Estado',
                        style: WorkflowTheme.bodyText.copyWith(
                          fontWeight: WorkflowDesignConstants.fontSemiBold,
                        ),
                      ),
                      const SizedBox(height: WorkflowDesignConstants.spacingSm),
                      TextFormField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              WorkflowDesignConstants.radiusMd,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: WorkflowDesignConstants.spacing,
                            vertical: WorkflowDesignConstants.spacingMd,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: WorkflowDesignConstants.spacingLg),

                      // Estado Base (Solo en servicio)
                      if (widget.modulo == 'servicio' && widget.estadosBase.isNotEmpty) ...[
                        Text(
                          'Estado Base del Sistema',
                          style: WorkflowTheme.bodyText.copyWith(
                            fontWeight: WorkflowDesignConstants.fontSemiBold,
                          ),
                        ),
                        const SizedBox(
                          height: WorkflowDesignConstants.spacingSm,
                        ),
                        DropdownButtonFormField<String>(
                          value: _estadoBaseSeleccionado,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                WorkflowDesignConstants.radiusMd,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: WorkflowDesignConstants.spacing,
                              vertical: WorkflowDesignConstants.spacingMd,
                            ),
                          ),
                          items:
                              widget.estadosBase.map((eb) {
                                return DropdownMenuItem<String>(
                                  value: eb['codigo'],
                                  child: Text(eb['nombre'] ?? eb['codigo']),
                                );
                              }).toList(),
                          onChanged:
                              widget.isProtected
                                  ? null
                                  : (value) {
                                    setState(() {
                                      _estadoBaseSeleccionado = value;
                                      // Auto-sincronizar flags si se cambia el base
                                      if (value != null) {
                                        final base = widget.estadosBase
                                            .firstWhere(
                                              (eb) => eb['codigo'] == value,
                                              orElse: () => {},
                                            );
                                        if (base.containsKey('es_final')) {
                                          _esFinal =
                                              (int.tryParse(
                                                    base['es_final'].toString(),
                                                  ) ??
                                                  0) ==
                                              1;
                                        }
                                      }
                                    });
                                  },
                        ),
                        const SizedBox(
                          height: WorkflowDesignConstants.spacingLg,
                        ),
                      ],

                      // Color
                      Text(
                        'Color Identificador',
                        style: WorkflowTheme.bodyText.copyWith(
                          fontWeight: WorkflowDesignConstants.fontSemiBold,
                        ),
                      ),
                      const SizedBox(height: WorkflowDesignConstants.spacingMd),
                      ColorPickerWidget(
                        selectedColor: _colorSeleccionado,
                        onColorSelected: (color) {
                          setState(() => _colorSeleccionado = color);
                        },
                      ),

                      const SizedBox(height: WorkflowDesignConstants.spacingLg),

                      // Toggles (Solo mostrar si el modulo es servicio y el estado base es final)
                      if (widget.modulo == 'servicio' && (() {
                        if (_estadoBaseSeleccionado == null) return false;
                        final base = widget.estadosBase.firstWhere(
                          (eb) => eb['codigo'] == _estadoBaseSeleccionado,
                          orElse: () => {},
                        );
                        return (int.tryParse(
                                  base['es_final']?.toString() ?? '0',
                                ) ??
                                0) ==
                            1;
                      }()))
                        Container(
                          margin: const EdgeInsets.only(
                            top: WorkflowDesignConstants.spacing,
                          ),
                          padding: const EdgeInsets.all(
                            WorkflowDesignConstants.spacing,
                          ),
                          decoration: BoxDecoration(
                            color: WorkflowTheme.surface,
                            borderRadius: BorderRadius.circular(
                              WorkflowDesignConstants.radiusMd,
                            ),
                            border: Border.all(color: WorkflowTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Bloquea Cierre'),
                                subtitle: Text(
                                  'Si se activa, el servicio no pasará a contabilidad automáticamente. Útil si quieres que un supervisor valide el trabajo antes de que se considere "Terminado".',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: WorkflowTheme.textSecondary,
                                  ),
                                ),
                                value: _bloqueaCierre,
                                activeThumbColor: WorkflowTheme.primaryPurple,
                                onChanged: (value) {
                                  setState(() => _bloqueaCierre = value);
                                },
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
              decoration: BoxDecoration(
                color: WorkflowTheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(WorkflowDesignConstants.radiusLg),
                  bottomRight: Radius.circular(
                    WorkflowDesignConstants.radiusLg,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: WorkflowTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: WorkflowDesignConstants.spacingMd),
                  ElevatedButton(
                    onPressed: _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WorkflowTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: WorkflowDesignConstants.spacingLg,
                        vertical: WorkflowDesignConstants.spacingMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          WorkflowDesignConstants.radiusMd,
                        ),
                      ),
                    ),
                    child: const Text('Guardar Cambios'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
