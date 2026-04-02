/// ============================================================================
/// ARCHIVO: crear_servicio_dialog.dart
///
/// PROPÓSITO: Diálogo para crear un servicio desde una actividad autorizada
/// - Seleccionar cliente
/// - Ingresar número de orden
/// - Configurar detalles del servicio
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:infoapp/main.dart';
import '../models/inspeccion_model.dart';

class CrearServicioDialog extends StatefulWidget {
  final ActividadInspeccionModel actividad;
  final int inspeccionId;
  final String equipoNombre;
  final Function(Map<String, dynamic>) onCrear;

  const CrearServicioDialog({
    super.key,
    required this.actividad,
    required this.inspeccionId,
    required this.equipoNombre,
    required this.onCrear,
  });

  @override
  State<CrearServicioDialog> createState() => _CrearServicioDialogState();
}

class _CrearServicioDialogState extends State<CrearServicioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ordenClienteController = TextEditingController();
  final _notasController = TextEditingController();
  
  int? _clienteIdSeleccionado;
  bool _isCreating = false;

  @override
  void dispose() {
    _ordenClienteController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Crear Servicio desde Actividad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Contenido
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información de la actividad
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Información de la Actividad',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow('Actividad:', widget.actividad.actividadNombre ?? 'N/A'),
                            _buildInfoRow('Equipo:', widget.equipoNombre),
                            if (widget.actividad.actividadDescripcion != null)
                              _buildInfoRow('Descripción:', widget.actividad.actividadDescripcion!),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Selector de cliente
                      DropdownButtonFormField<int>(
                        initialValue: _clienteIdSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Cliente *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                          hintText: 'Seleccione el cliente',
                        ),
                        items: const [
                          // TODO: Cargar clientes desde el backend
                          DropdownMenuItem(value: 1, child: Text('Cliente Ejemplo 1')),
                          DropdownMenuItem(value: 2, child: Text('Cliente Ejemplo 2')),
                          DropdownMenuItem(value: 3, child: Text('Cliente Ejemplo 3')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _clienteIdSeleccionado = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Debe seleccionar un cliente';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Número de orden del cliente
                      TextFormField(
                        controller: _ordenClienteController,
                        decoration: const InputDecoration(
                          labelText: 'Número de Orden del Cliente',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt_long),
                          hintText: 'Ej: OC-2024-001',
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Notas adicionales
                      TextFormField(
                        controller: _notasController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notas Adicionales',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                          hintText: 'Información adicional sobre el servicio...',
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Nota informativa
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Se creará un nuevo servicio basado en esta actividad de inspección. '
                                'El servicio heredará la información del equipo y la actividad.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Botones de acción
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCreating ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add_circle),
                    label: Text(_isCreating ? 'Creando...' : 'Crear Servicio'),
                    onPressed: _isCreating ? null : _crearServicio,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _crearServicio() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final datos = {
        'inspeccion_id': widget.inspeccionId,
        'actividad_id': widget.actividad.id,
        'cliente_id': _clienteIdSeleccionado,
        'orden_cliente': _ordenClienteController.text.trim(),
        'notas': _notasController.text.trim(),
      };

      widget.onCrear(datos);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      MyApp.showSnackBar('Error: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}
