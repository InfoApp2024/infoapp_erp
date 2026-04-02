/// ============================================================================
/// ARCHIVO: actividades_list.dart
///
/// PROPÓSITO: Lista de actividades de inspección
/// - Mostrar actividades asociadas
/// - Autorizar/desautorizar actividades
/// - Crear servicios desde actividades autorizadas
/// - Agregar notas
/// ============================================================================
library;

import 'package:flutter/material.dart';
import '../models/inspeccion_model.dart';

class ActividadesList extends StatelessWidget {
  final List<ActividadInspeccionModel> actividades;
  final Function(int actividadId, bool autorizada)? onCambiarAutorizacion;
  final Function(int actividadId)? onCrearServicio;
  final Function(int actividadId, String notas)? onAgregarNotas;
  final bool readOnly;

  const ActividadesList({
    super.key,
    required this.actividades,
    this.onCambiarAutorizacion,
    this.onCrearServicio,
    this.onAgregarNotas,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Actividades de Inspección',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${actividades.length} actividad(es) • ${actividades.where((a) => a.autorizada == true).length} autorizada(s)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (actividades.isEmpty)
              _buildEstadoVacio()
            else
              _buildLista(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay actividades asignadas',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actividades.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final actividad = actividades[index];
        return _buildActividadCard(context, actividad);
      },
    );
  }

  Widget _buildActividadCard(BuildContext context, ActividadInspeccionModel actividad) {
    final isAutorizada = actividad.autorizada ?? false;
    final yaSeCreoServicio = actividad.yaSeCreoServicio;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Checkbox de autorización
              if (!readOnly)
                Checkbox(
                  value: isAutorizada,
                  onChanged: (value) {
                    if (onCambiarAutorizacion != null && !yaSeCreoServicio) {
                      onCambiarAutorizacion!(actividad.id!, value ?? false);
                    }
                  },
                )
              else
                Icon(
                  isAutorizada ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isAutorizada ? Colors.green : Colors.grey,
                ),
              
              const SizedBox(width: 8),
              
              // Información de la actividad
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actividad.actividadNombre ?? 'Actividad sin nombre',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: yaSeCreoServicio ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (actividad.actividadDescripcion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        actividad.actividadDescripcion!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    
                    // Estado y badges
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (isAutorizada)
                          _buildBadge(
                            'Autorizada',
                            Colors.green,
                            Icons.check_circle,
                          ),
                        if (yaSeCreoServicio)
                          _buildBadge(
                            actividad.servicioNumeroFormateado,
                            Colors.blue,
                            Icons.build,
                          ),
                        if (actividad.autorizadoPorNombre != null)
                          _buildBadge(
                            'Por: ${actividad.autorizadoPorNombre}',
                            Colors.grey,
                            Icons.person,
                          ),
                      ],
                    ),
                    
                    // Notas
                    if (actividad.notas != null && actividad.notas!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.note, size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                actividad.notas!,
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
                  ],
                ),
              ),
              
              // Acciones
              if (!readOnly && isAutorizada) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'crear_servicio':
                        if (onCrearServicio != null && !yaSeCreoServicio) {
                          onCrearServicio!(actividad.id!);
                        }
                        break;
                      case 'agregar_notas':
                        if (onAgregarNotas != null) {
                          _mostrarDialogoNotas(context, actividad);
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!yaSeCreoServicio)
                      const PopupMenuItem(
                        value: 'crear_servicio',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle, size: 20),
                            SizedBox(width: 8),
                            Text('Crear Servicio'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'agregar_notas',
                      child: Row(
                        children: [
                          Icon(Icons.note_add, size: 20),
                          SizedBox(width: 8),
                          Text('Agregar Notas'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoNotas(BuildContext context, ActividadInspeccionModel actividad) {
    final controller = TextEditingController(text: actividad.notas);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Notas'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Ingrese notas o comentarios sobre esta actividad...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onAgregarNotas != null) {
                onAgregarNotas!(actividad.id!, controller.text);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
