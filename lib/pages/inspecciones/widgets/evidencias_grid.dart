/// ============================================================================
/// ARCHIVO: evidencias_grid.dart
///
/// PROPÓSITO: Grid para mostrar y gestionar evidencias fotográficas
/// - Visualización en cuadrícula
/// - Subir nuevas fotos
/// - Agregar comentarios
/// - Eliminar evidencias
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:infoapp/main.dart';
import 'package:image_picker/image_picker.dart';
import '../models/inspeccion_model.dart';

class EvidenciasGrid extends StatefulWidget {
  final int inspeccionId;
  final List<EvidenciaModel> evidencias;
  final Function(XFile) onAgregarEvidencia;
  final Function(int) onEliminarEvidencia;
  final bool readOnly;

  const EvidenciasGrid({
    super.key,
    required this.inspeccionId,
    required this.evidencias,
    required this.onAgregarEvidencia,
    required this.onEliminarEvidencia,
    this.readOnly = false,
  });

  @override
  State<EvidenciasGrid> createState() => _EvidenciasGridState();
}

class _EvidenciasGridState extends State<EvidenciasGrid> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_library, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Evidencias Fotográficas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (!widget.readOnly)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_a_photo, size: 18),
                    label: const Text('Agregar Foto'),
                    onPressed: _seleccionarImagen,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.evidencias.length} foto(s) adjunta(s)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (widget.evidencias.isEmpty)
              _buildEstadoVacio()
            else
              _buildGrid(),
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
            Icon(Icons.photo_camera, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              widget.readOnly
                  ? 'No hay evidencias fotográficas'
                  : 'No hay fotos adjuntas aún',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(height: 8),
              Text(
                'Toca el botón "Agregar Foto" para subir evidencias',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: widget.evidencias.length,
      itemBuilder: (context, index) {
        final evidencia = widget.evidencias[index];
        return _buildEvidenciaCard(evidencia);
      },
    );
  }

  Widget _buildEvidenciaCard(EvidenciaModel evidencia) {
    return GestureDetector(
      onTap: () => _verEvidenciaDetalle(evidencia),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagen
            if (evidencia.rutaImagen != null)
              Image.network(
                evidencia.rutaImagen!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              )
            else
              Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, size: 48, color: Colors.grey),
              ),
            
            // Overlay con información
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (evidencia.comentario != null && evidencia.comentario!.isNotEmpty)
                      Text(
                        evidencia.comentario!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            
            // Botón eliminar
            if (!widget.readOnly)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _confirmarEliminar(evidencia),
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (imagen != null) {
        widget.onAgregarEvidencia(imagen);
      }
    } catch (e) {
      MyApp.showSnackBar('Error al seleccionar imagen: $e', backgroundColor: Colors.red);
    }
  }

  void _verEvidenciaDetalle(EvidenciaModel evidencia) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
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
                    const Icon(Icons.photo, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Detalle de Evidencia',
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
              
              // Imagen
              Expanded(
                child: evidencia.rutaImagen != null
                    ? InteractiveViewer(
                        child: Image.network(
                          evidencia.rutaImagen!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Error al cargar imagen'),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : const Center(child: Text('No hay imagen disponible')),
              ),
              
              // Información
              if (evidencia.comentario != null || evidencia.creadoPorNombre != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (evidencia.comentario != null) ...[
                        const Text(
                          'Comentario:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          evidencia.comentario!,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (evidencia.creadoPorNombre != null)
                        Text(
                          'Subido por: ${evidencia.creadoPorNombre}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (evidencia.createdAt != null)
                        Text(
                          'Fecha: ${evidencia.createdAt}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(EvidenciaModel evidencia) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Evidencia'),
        content: const Text('¿Está seguro de que desea eliminar esta evidencia fotográfica?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onEliminarEvidencia(evidencia.id!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
