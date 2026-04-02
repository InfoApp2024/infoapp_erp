import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/foundation.dart';
import 'package:infoapp/pages/inspecciones/models/evidencia_seleccionada.dart';

class SelectorEvidencias extends StatefulWidget {
  final List<EvidenciaSeleccionada> evidencias;
  final Map<int, String> actividadesDisponibles;
  final bool showError;
  final Function(List<EvidenciaSeleccionada>) onChanged;

  const SelectorEvidencias({
    super.key,
    required this.evidencias,
    required this.actividadesDisponibles,
    this.showError = false,
    required this.onChanged,
  });

  @override
  State<SelectorEvidencias> createState() => _SelectorEvidenciasState();
}

class _SelectorEvidenciasState extends State<SelectorEvidencias> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _agregarEvidencia(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Optimizar tamaño
      );

      if (photo != null) {
        final nuevasEvidencias = List<EvidenciaSeleccionada>.from(widget.evidencias);
        nuevasEvidencias.add(EvidenciaSeleccionada(file: photo));
        widget.onChanged(nuevasEvidencias);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
    }
  }

  void _eliminarEvidencia(int index) {
    final nuevasEvidencias = List<EvidenciaSeleccionada>.from(widget.evidencias);
    nuevasEvidencias.removeAt(index);
    widget.onChanged(nuevasEvidencias);
  }

  void _actualizarComentario(int index, String comentario) {
    widget.evidencias[index].comentario = comentario;
  }

  void _actualizarActividad(int index, int? actividadId) {
    setState(() {
      widget.evidencias[index].actividadId = actividadId;
      widget.onChanged(widget.evidencias);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: widget.showError 
        ? RoundedRectangleBorder(
            side: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(12),
          )
        : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Evidencias y Fotos *',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_a_photo),
                  tooltip: 'Tomar Foto',
                  onPressed: () => _agregarEvidencia(ImageSource.camera),
                ),
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate),
                  tooltip: 'Galería',
                  onPressed: () => _agregarEvidencia(ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 8),
             if (widget.evidencias.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No hay evidencias agregadas.',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.evidencias.length,
                itemBuilder: (context, index) {
                  final evidencia = widget.evidencias[index];
                  // Validar que el actividadId siga siendo válido (por si se eliminó de la lista de actividades)
                  if (evidencia.actividadId != null && !widget.actividadesDisponibles.containsKey(evidencia.actividadId)) {
                    evidencia.actividadId = null;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isNarrow = constraints.maxWidth < 350;
                        
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (evidencia.isRemote || evidencia.file.path.startsWith('http'))
                                  ? Image.network(
                                      evidencia.file.path,
                                      width: isNarrow ? 60 : 80,
                                      height: isNarrow ? 60 : 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: isNarrow ? 60 : 80,
                                        height: isNarrow ? 60 : 80,
                                        color: Colors.grey[200],
                                        child: Icon(Icons.broken_image, color: Colors.grey, size: isNarrow ? 20 : 24),
                                      ),
                                    )
                                  : kIsWeb
                                      ? Image.network(
                                          evidencia.file.path,
                                          width: isNarrow ? 60 : 80,
                                          height: isNarrow ? 60 : 80,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(evidencia.file.path),
                                          width: isNarrow ? 60 : 80,
                                          height: isNarrow ? 60 : 80,
                                          fit: BoxFit.cover,
                                        ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<int>(
                                    initialValue: evidencia.actividadId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Actividad *',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      isDense: false,
                                    ),
                                    style: TextStyle(fontSize: isNarrow ? 13 : 14, color: Colors.black),
                                    items: widget.actividadesDisponibles.entries.where((e) {
                                      if (e.key == evidencia.actividadId) return true;
                                      return !widget.evidencias.any((ev) => ev.actividadId == e.key);
                                    }).map((e) {
                                      return DropdownMenuItem<int>(
                                        value: e.key,
                                        child: Text(
                                          e.value,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: isNarrow ? 13 : 14),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) => _actualizarActividad(index, val),
                                    validator: (val) => val == null ? 'Requerido' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    initialValue: evidencia.comentario,
                                    decoration: const InputDecoration(
                                      labelText: 'Comentario / Observación',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      isDense: false,
                                      hintText: 'Ej: Se evidencia desgaste...',
                                    ),
                                    style: TextStyle(fontSize: isNarrow ? 13 : 14),
                                    maxLines: null,
                                    minLines: 1,
                                    onChanged: (val) => _actualizarComentario(index, val),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _eliminarEvidencia(index),
                            ),
                          ],
                        );
                      }
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
