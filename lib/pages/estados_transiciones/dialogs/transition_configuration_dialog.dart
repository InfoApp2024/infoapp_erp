import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';

class TransitionConfigurationDialog extends StatefulWidget {
  final String? initialName;
  final String? initialTrigger;
  final String modulo;
  final List<String> usedTriggers;

  const TransitionConfigurationDialog({
    super.key,
    required this.modulo,
    this.initialName,
    this.initialTrigger,
    this.usedTriggers = const [],
  });

  @override
  State<TransitionConfigurationDialog> createState() => _TransitionConfigurationDialogState();
}

class _TransitionConfigurationDialogState extends State<TransitionConfigurationDialog> {
  late String _selectedTrigger;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _selectedTrigger = widget.initialTrigger ?? 'MANUAL';
    _nameController = TextEditingController(text: widget.initialName ?? 'Nueva Transición');
  }

  final List<Map<String, dynamic>> _triggers = [
    {
      'code': 'MANUAL',
      'label': 'Manual',
      'description': 'El usuario debe avanzar manualmente.',
      'icon': Icons.touch_app,
      'color': Colors.grey,
    },
    {
      'code': 'FIRMA_CLIENTE',
      'label': 'Firma de Cliente',
      'description': 'Avanza automáticamente al recibir firma.',
      'icon': Icons.draw,
      'color': Colors.blue,
    },
    {
      'code': 'FOTO_SUBIDA',
      'label': 'Foto de Evidencia',
      'description': 'Avanza automáticamente al subir fotos.',
      'icon': Icons.camera_alt,
      'color': Colors.purple,
    },
    {
      'code': 'OS_REPUESTOS',
      'label': 'OS Repuestos',
      'description': 'Avanza automáticamente al gestionar repuestos.',
      'icon': Icons.build_circle,
      'color': Colors.orange,
    },
    {
      'code': 'ASIGNAR_PERSONAL',
      'label': 'Asignar Personal',
      'description': 'Requiere al menos un técnico asignado para avanzar.',
      'icon': Icons.people_outline,
      'color': Colors.teal,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar Transición'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Transición',
                hintText: 'Ej: Aprobar, Enviar a Revisión',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.modulo == 'servicio') ...[
              const SizedBox(height: WorkflowDesignConstants.spacingLg),
              
              // Selector de Trigger
              const Text(
                'Disparador (Trigger)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: WorkflowDesignConstants.spacingSm),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: WorkflowTheme.border),
                  borderRadius: BorderRadius.circular(WorkflowDesignConstants.radiusMd),
                ),
                child: Column(
                  children: _triggers.map((trigger) {
                    final isSelected = _selectedTrigger == trigger['code'];
                    return InkWell(
                      onTap: () => setState(() => _selectedTrigger = trigger['code']),
                      child: Container(
                        padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
                        color: isSelected ? WorkflowTheme.primaryPurple.withOpacity(0.1) : null,
                        child: Row(
                          children: [
                            Icon(
                              trigger['icon'],
                              color: isSelected ? WorkflowTheme.primaryPurple : Colors.grey,
                            ),
                            const SizedBox(width: WorkflowDesignConstants.spacingMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        trigger['label'],
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color:
                                              isSelected
                                                  ? WorkflowTheme.primaryPurple
                                                  : Colors.black87,
                                        ),
                                      ),
                                      if (widget.usedTriggers.contains(
                                            trigger['code'],
                                          ) &&
                                          trigger['code'] != 'MANUAL') ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.red[200]!,
                                            ),
                                          ),
                                          child: const Text(
                                            'YA EN USO',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    trigger['description'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: WorkflowTheme.primaryPurple,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Cancelar
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final String name = _nameController.text.trim();
            final String trigger = _selectedTrigger;

            // Validación extra en el botón
            if (trigger != 'MANUAL' &&
                widget.usedTriggers.contains(trigger) &&
                trigger != widget.initialTrigger) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Este disparador ya está en uso. Por favor elige otro.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('El nombre no puede estar vacío'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.of(context).pop({'nombre': name, 'trigger_code': trigger});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: WorkflowTheme.primaryPurple,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.initialName == null ? 'Crear Transición' : 'Guardar Cambios'),
        ),
      ],
    );
  }
}
