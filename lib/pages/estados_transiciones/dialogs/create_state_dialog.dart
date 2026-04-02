import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';
import '../widgets/color_picker_widget.dart';

/// Modal mejorado para crear un nuevo estado
class CreateStateDialog extends StatefulWidget {
  final List<Map<String, dynamic>> estadosBase;
  final Function(Map<String, dynamic>) onCreate;
  final String modulo;

  const CreateStateDialog({
    super.key,
    required this.estadosBase,
    required this.onCreate,
    required this.modulo,
  });

  @override
  State<CreateStateDialog> createState() => _CreateStateDialogState();
}

class _CreateStateDialogState extends State<CreateStateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ordenController = TextEditingController(text: '0');

  String _colorSeleccionado = '#2196F3'; // Azul por defecto
  String? _estadoBaseSeleccionado;
  bool _bloqueaCierre = false;
  bool _esFinal = false;

  @override
  void initState() {
    super.initState();
    // Default para módulos que no requieren selección de base
    if (widget.modulo != 'servicio') {
      _estadoBaseSeleccionado = 'ABIERTO';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _ordenController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'nombre_estado': _nombreController.text.trim(),
      'color': _colorSeleccionado,
      'codigo_base': _estadoBaseSeleccionado,
      'bloquea_cierre': _bloqueaCierre ? 1 : 0,
      'es_final': _esFinal ? 1 : 0,
      'orden': int.tryParse(_ordenController.text) ?? 0,
    };

    widget.onCreate(data);
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
            // Header con gradiente
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
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: WorkflowDesignConstants.iconLg,
                  ),
                  const SizedBox(width: WorkflowDesignConstants.spacingMd),
                  const Expanded(
                    child: Text(
                      'Crear Nuevo Estado',
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

            // Contenido del formulario
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
                      // Nombre del estado
                      Text(
                        'Nombre del Estado',
                        style: WorkflowTheme.bodyText.copyWith(
                          fontWeight: WorkflowDesignConstants.fontSemiBold,
                        ),
                      ),
                      const SizedBox(height: WorkflowDesignConstants.spacingSm),
                      TextFormField(
                        controller: _nombreController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Ej: En Revisión',
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

                      // Estado Base del Sistema (Solo en servicio)
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
                            hintText: 'Seleccione un estado base',
                            helperText: 'Categoría semántica para analytics',
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
                          onChanged: (value) {
                            setState(() => _estadoBaseSeleccionado = value);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Seleccione un estado base';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(
                          height: WorkflowDesignConstants.spacingLg,
                        ),
                      ],

                      // Color Identificador
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

                      // Toggles (Solo mostrar si el módulo es servicio y el estado base es final)
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

            // Footer con botones
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
                    onPressed: _handleCreate,
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
                    child: const Text('Guardar Estado'),
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
