import 'package:flutter/material.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import '../../services/servicios_sync_queue.dart';
import '../../models/foto_model.dart';
import '../../services/fotos_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:infoapp/features/auth/data/auth_service.dart';

enum FotoViewMode { individual, comparativa }

/// Widget especializado para gestión de fotos del servicio
class FotosServicioWidget extends StatefulWidget {
  final int servicioId;
  final String numeroServicio;
  final bool enabled;
  final VoidCallback? onFotosChanged;

  const FotosServicioWidget({
    super.key,
    required this.servicioId,
    required this.numeroServicio,
    this.enabled = true,
    this.onFotosChanged,
  });

  @override
  State<FotosServicioWidget> createState() => _FotosServicioWidgetState();
}

class _FotosServicioWidgetState extends State<FotosServicioWidget> {
  List<FotoModel> _fotos = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _authToken;
  String _selectedTipo = 'antes'; // 'antes' o 'despues'
  FotoViewMode _viewMode = FotoViewMode.individual;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _cargarFotos();
  }

  Future<void> _loadToken() async {
    final token = await AuthService.getBearerToken();
    if (mounted) {
      setState(() => _authToken = token);
    }
  }

  Future<void> _cargarFotos() async {
    setState(() => _isLoading = true);

    try {
      final fotos = await FotosService.obtenerFotosServicio(widget.servicioId);
      if (mounted) {
        setState(() => _fotos = fotos);
        widget.onFotosChanged?.call();
      }
    } catch (e) {
      //       print('? Error cargando fotos: $e');
      _mostrarError('Error cargando fotos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _seleccionarYSubirFoto(String tipo) async {
    if (!widget.enabled) return;

    // Mostrar opciones: Cámara o Galería
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  tipo == 'antes' ? PhosphorIcons.cameraPlus() : PhosphorIcons.camera(),
                  color:
                      tipo == 'antes'
                          ? Colors.orange.shade600
                          : Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seleccionar Foto ${tipo.toUpperCase()}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¿Cómo quieres obtener la imagen?'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.info(), color: Theme.of(context).primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          kIsWeb 
                            ? 'Tip: Selecciona una imagen de tu equipo.' 
                            : 'Tip: La cámara es ideal para fotos inmediatas, la galería para imágenes ya guardadas.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: Icon(PhosphorIcons.images()),
                label: const Text('Galería'),
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
              ),
              if (!kIsWeb)
                TextButton.icon(
                  icon: Icon(PhosphorIcons.camera()),
                  label: const Text('Cámara'),
                  onPressed: () => Navigator.pop(context, ImageSource.camera),
                ),
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );

    if (source == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _isUploading = true);

        _mostrarMensajeCarga('Subiendo foto $tipo...');

        // Calcular índice de pareja automáticamente
        int? pairIndex;
        try {
          // Mapear conteos por índice
          final antesCount = <int, int>{};
          final despuesCount = <int, int>{};
          for (final f in _fotos) {
            // Usar ordenVisualizacion si existe (>0), sino intentar leer de la descripción (legacy)
            final idx =
                f.ordenVisualizacion > 0 ? f.ordenVisualizacion : f.pairIndex;
            if (idx == null || idx == 0) continue;

            if (f.tipoFoto.toLowerCase() == 'antes') {
              antesCount[idx] = (antesCount[idx] ?? 0) + 1;
            } else if (f.tipoFoto.toLowerCase() == 'despues') {
              despuesCount[idx] = (despuesCount[idx] ?? 0) + 1;
            }
          }

          int siguiente = 1;
          final usados =
              <int>{}
                ..addAll(antesCount.keys)
                ..addAll(despuesCount.keys);
          if (usados.isNotEmpty) {
            siguiente = (usados.reduce((a, b) => a > b ? a : b)) + 1;
          }

          if (tipo.toLowerCase() == 'antes') {
            pairIndex = siguiente; // Siempre crea el siguiente grupo
          } else {
            // Intentar asociar a un grupo con ANTES sin DESPUÉS
            final candidatos = antesCount.keys.toList()..sort();
            for (final idx in candidatos) {
              final a = antesCount[idx] ?? 0;
              final d = despuesCount[idx] ?? 0;
              if (a > d) {
                // Falta "después" para este grupo
                pairIndex = idx;
                break;
              }
            }
            pairIndex ??= siguiente; // Si no hay candidatos, crear nuevo grupo
          }
        } catch (_) {}

        // Chequear conectividad y encolar si está offline
        final isOnline = await ConnectivityService.instance.checkNow();
        if (!isOnline) {
          if (kIsWeb) {
            _mostrarError('En la web no se permite trabajar sin conexión.');
            return;
          }
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          final extension = image.name.split('.').last.toLowerCase();
          final fileName =
              'servicio_${widget.servicioId}_${tipo}_${DateTime.now().millisecondsSinceEpoch}.$extension';
          final descripcion =
              pairIndex != null
                  ? '[PAIR:$pairIndex] Foto $tipo del servicio #${widget.servicioId}'
                  : 'Foto $tipo del servicio #${widget.servicioId}';

          await ServiciosSyncQueue.enqueueSubirFoto(
            servicioId: widget.servicioId,
            tipoFoto: tipo,
            descripcion: descripcion,
            imagenBase64: base64Image,
            nombreArchivo: fileName,
          );
          _mostrarExito('Sin conexión: subida encolada para sincronizar');
          return;
        }

        final exito = await FotosService.subirFoto(
          widget.servicioId,
          image,
          tipo,
          pairIndex: pairIndex,
        );

        if (exito) {
          _mostrarExito('Foto $tipo subida exitosamente');
          await _cargarFotos(); // Recargar fotos
        } else {
          _mostrarError('Error subiendo foto');
        }
      }
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  Future<void> _moverFoto(FotoModel foto, int direccion) async {
    // direccion: -1 (subir/atrás), 1 (bajar/adelante)
    final fotosDelTipo =
        _fotos.where((f) => f.tipoFoto == foto.tipoFoto).toList()..sort((a, b) {
          final cmp = a.ordenVisualizacion.compareTo(b.ordenVisualizacion);
          if (cmp != 0) return cmp;
          return a.fechaSubida.compareTo(b.fechaSubida);
        });

    final index = fotosDelTipo.indexWhere((f) => f.id == foto.id);
    if (index == -1) return;

    final newIndex = index + direccion;
    if (newIndex < 0 || newIndex >= fotosDelTipo.length) return;

    // Obtener lista de IDs ordenada actual
    final orderedIds = fotosDelTipo.map((f) => f.id).toList();

    // Intercambiar posiciones
    final temp = orderedIds[index];
    orderedIds[index] = orderedIds[newIndex];
    orderedIds[newIndex] = temp;

    // Crear payload de actualización
    // Asignamos orden secuencial (1, 2, 3...)
    List<Map<String, dynamic>> ordenes = [];
    for (int i = 0; i < orderedIds.length; i++) {
      ordenes.add({'id': orderedIds[i], 'orden': i + 1});
    }

    setState(() => _isLoading = true);

    try {
      // Verificar conexión
      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        if (kIsWeb) {
          _mostrarError('En la web no se permite trabajar sin conexión.');
          setState(() => _isLoading = false);
          return;
        }

        // Encolar reordenamiento
        await ServiciosSyncQueue.enqueueReordenarFotos(
          servicioId: widget.servicioId,
          ordenes: ordenes,
        );

        // Actualizar UI localmente
        setState(() {
          for (int i = 0; i < orderedIds.length; i++) {
            final id = orderedIds[i];
            final fotoIndex = _fotos.indexWhere((f) => f.id == id);
            if (fotoIndex != -1) {
              _fotos[fotoIndex] = _fotos[fotoIndex].copyWith(
                ordenVisualizacion: i + 1,
              );
            }
          }
          _isLoading = false;
        });

        _mostrarExito('Sin conexión: orden actualizado y encolado');
        return;
      }

      final success = await FotosService.reordenarFotos(
        widget.servicioId,
        ordenes,
      );

      if (success) {
        // Recargar para ver cambios
        // (El backend ya actualizó la BD, así que cargarFotos traerá el nuevo orden)
        await _cargarFotos();
        _mostrarExito('Orden actualizado');
      } else {
        _mostrarError('Error al guardar el nuevo orden');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _mostrarError('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarFoto(FotoModel foto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(PhosphorIcons.trash(), color: Colors.red.shade600),
                const SizedBox(width: 8),
                const Text('Eliminar Foto'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Estás seguro de que quieres eliminar esta foto ${foto.tipoFoto}?',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.warning(),
                        color: Colors.orange.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta acción no se puede deshacer.',
                          style: TextStyle(
                            fontSize: 12,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      try {
        // Chequear conectividad y encolar si está offline
        final isOnline = await ConnectivityService.instance.checkNow();
        if (!isOnline) {
          if (kIsWeb) {
            _mostrarError('En la web no se permite trabajar sin conexión.');
            return;
          }
          await ServiciosSyncQueue.enqueueEliminarFoto(fotoId: foto.id);
          _mostrarExito('Sin conexión: eliminación encolada para sincronizar');
          return;
        }

        final exito = await FotosService.eliminarFoto(foto.id);
        if (exito) {
          _mostrarExito('Foto eliminada exitosamente');
          await _cargarFotos(); // Recargar fotos
        } else {
          _mostrarError('Error eliminando foto');
        }
      } catch (e) {
        _mostrarError('Error: $e');
      }
    }
  }

  void _verFotoCompleta(FotoModel foto) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con información
                  Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          foto.tipoFoto == 'antes'
                              ? PhosphorIcons.cameraPlus()
                              : PhosphorIcons.camera(),
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foto ${foto.tipoFoto.toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Servicio #${widget.numeroServicio}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(PhosphorIcons.x(), color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Imagen
                  Flexible(
                    child: Container(
                      color: Colors.black,
                      child: Image.network(
                        foto.urlImagen,
                        headers:
                            _authToken != null
                                ? {'Authorization': _authToken!}
                                : null,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Cargando imagen...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PhosphorIcons.image(),
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Error cargando imagen',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'URL: ${foto.urlImagen}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Footer con descripción si existe
                  if (foto.descripcion != null && foto.descripcion!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: Colors.black87,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        foto.descripcion!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      NetErrorMessages.showMessage(context, mensaje, success: false);
    }
  }

  void _mostrarExito(String mensaje) {
    if (mounted) {
      NetErrorMessages.showMessage(context, mensaje, success: true);
    }
  }

  void _mostrarMensajeCarga(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
          duration: const Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Selector de Modo (Individual vs Comparativa)
        Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              _buildModeToggleButton(
                FotoViewMode.individual,
                'Vista Por Estados',
                PhosphorIcons.stack(),
              ),
              _buildModeToggleButton(
                FotoViewMode.comparativa,
                'Vista Comparativa',
                PhosphorIcons.columns(),
              ),
            ],
          ),
        ),

        // Selector Segmentado de tipo de foto (Solo visible en modo individual)
        if (_viewMode == FotoViewMode.individual)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  'antes',
                  'Fotos ANTES',
                  PhosphorIcons.cameraPlus(),
                ),
                _buildTabButton(
                  'despues',
                  'Fotos DESPUÉS',
                  PhosphorIcons.camera(),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Botón para agregar fotos (Solo en modo individual)
        if (widget.enabled && _viewMode == FotoViewMode.individual)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                _selectedTipo == 'antes' ? PhosphorIcons.cameraPlus() : PhosphorIcons.camera(),
                size: 20,
              ),
              label: Text(
                _selectedTipo == 'antes' ? 'Tomar Foto ANTES' : 'Tomar Foto DESPUÉS',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                foregroundColor: theme.primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isUploading || _isLoading ? null : () => _seleccionarYSubirFoto(_selectedTipo),
            ),
          ),

        const SizedBox(height: 24),

        // Cuerpo de la sección de fotos
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando evidencias...'),
                ],
              ),
            ),
          )
        else if (_isUploading)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Subiendo fotografía...')),
              ],
            ),
          )
        else if (_viewMode == FotoViewMode.comparativa)
          _buildModoComparativa(theme)
        else
          _buildSeccionFotos(
            _selectedTipo,
            _selectedTipo == 'antes' ? 'Fotos del Estado Inicial' : 'Fotos del Estado Final',
            theme.primaryColor,
          ),
      ],
    );
  }

  Widget _buildModeToggleButton(FotoViewMode mode, String label, IconData icon) {
    final isSelected = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionFotos(String tipo, String titulo, Color color) {
    final fotosDelTipo =
        _fotos.where((foto) => foto.tipoFoto == tipo).toList()..sort((a, b) {
          final cmp = a.ordenVisualizacion.compareTo(b.ordenVisualizacion);
          if (cmp != 0) return cmp;
          return a.fechaSubida.compareTo(b.fechaSubida);
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección
        Row(
          children: [
            Icon(
              tipo == 'antes' ? PhosphorIcons.cameraPlus() : PhosphorIcons.camera(),
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                '${fotosDelTipo.length} foto${fotosDelTipo.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Grid de fotos o estado vacío
        if (fotosDelTipo.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(
                  PhosphorIcons.image(),
                  color: Colors.grey.shade400,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay fotos $tipo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.enabled
                      ? 'Toca el botón "Tomar Foto ${tipo.toUpperCase()}" para agregar'
                      : 'No se han agregado fotos para este estado',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: fotosDelTipo.length,
            itemBuilder: (context, index) {
              final foto = fotosDelTipo[index];
              return _buildThumbnailFoto(foto);
            },
          ),
      ],
    );
  }

  Widget _buildThumbnailFoto(FotoModel foto) {
    return GestureDetector(
      onTap: () => _verFotoCompleta(foto),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen
              Image.network(
                foto.urlImagen,
                headers:
                    _authToken != null ? {'Authorization': _authToken!} : null,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.red.shade100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: Colors.red.shade400,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Error',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Botones de reordenamiento (solo si está habilitado)
              if (widget.enabled)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _moverFoto(foto, -1),
                          child: const Padding(
                            padding: EdgeInsets.all(4), // Reduced padding
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        Container(width: 1, height: 16, color: Colors.white30),
                        InkWell(
                          onTap: () => _moverFoto(foto, 1),
                          child: const Padding(
                            padding: EdgeInsets.all(4), // Reduced padding
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Botón eliminar (solo si está habilitado)
              if (widget.enabled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _eliminarFoto(foto),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

              // Badge de tipo
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    foto.tipoFoto.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Botón de vista completa
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModoComparativa(ThemeData theme) {
    // 1. Obtener listas separadas y ordenadas
    final antesList = _fotos.where((f) => f.tipoFoto.toLowerCase() == 'antes').toList()
      ..sort((a, b) {
        final cmp = a.ordenVisualizacion.compareTo(b.ordenVisualizacion);
        if (cmp != 0) return cmp;
        return a.fechaSubida.compareTo(b.fechaSubida);
      });

    final despuesList = _fotos.where((f) => f.tipoFoto.toLowerCase() == 'despues').toList()
      ..sort((a, b) {
        final cmp = a.ordenVisualizacion.compareTo(b.ordenVisualizacion);
        if (cmp != 0) return cmp;
        return a.fechaSubida.compareTo(b.fechaSubida);
      });

    final int maxRows = antesList.length > despuesList.length ? antesList.length : despuesList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHeaderColumna('ANTES', Colors.orange.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHeaderColumna('DESPUÉS', Colors.green.shade700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (maxRows == 0)
          _buildEstadoVacioComparativa()
        else ...[
          // Renderizar filas por índice
          ...List.generate(maxRows, (i) {
            final antes = i < antesList.length ? antesList[i] : null;
            final despues = i < despuesList.length ? despuesList[i] : null;
            // Usamos un pairIndex coherente para los botones "Agregar": 
            // intentamos usar el del otro elemento, o generamos uno secuencial
            final pIdx = antes?.pairIndex ?? despues?.pairIndex ?? (i + 1);
            return _buildFilaComparativa(pIdx, antes, despues);
          }),

          // Botón para nueva pareja (si habilitado y la última fila está completa)
          if (widget.enabled)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildBotonNuevoGrupo(theme),
            ),
        ],
      ],
    );
  }

  Widget _buildHeaderColumna(String titulo, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        titulo,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildFilaComparativa(int index, FotoModel? antes, FotoModel? despues) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna ANTES
          Expanded(
            child:
                antes != null
                    ? _buildThumbnailComparativo(antes)
                    : _buildSlotVacio('antes', index),
          ),
          const SizedBox(width: 12),
          // Columna DESPUÉS
          Expanded(
            child:
                despues != null
                    ? _buildThumbnailComparativo(despues)
                    : _buildSlotVacio('despues', index),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailComparativo(FotoModel foto) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImagenConLoading(foto),
          ),
          // Botón ver
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _verFotoCompleta(foto),
              ),
            ),
          ),
          // Botón eliminar
          if (widget.enabled)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _eliminarFoto(foto),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlotVacio(String tipo, int pairIndex) {
    if (!widget.enabled) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          ),
          child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 24),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _subirFotoManual(tipo, pairIndex),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tipo == 'antes' ? Colors.orange.shade300 : Colors.green.shade300,
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo,
                color: tipo == 'antes' ? Colors.orange.shade600 : Colors.green.shade600,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                'Agregar',
                style: TextStyle(
                  fontSize: 10,
                  color: tipo == 'antes' ? Colors.orange.shade700 : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildImagenConLoading(FotoModel foto) {
    return Image.network(
      foto.urlImagen,
      headers: _authToken != null ? {'Authorization': _authToken!} : null,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
      },
    );
  }

  Widget _buildEstadoVacioComparativa() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(PhosphorIcons.columns(), size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No hay parejas de fotos',
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Usa la vista individual para subir la primera foto o crea una nueva pareja aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (widget.enabled) ...[
            const SizedBox(height: 24),
            _buildBotonNuevoGrupo(Theme.of(context)),
          ]
        ],
      ),
    );
  }

  Widget _buildBotonNuevoGrupo(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          // Obtener el siguiente índice disponible
          int maxIdx = 0;
          for (final f in _fotos) {
            final idx = f.pairIndex ?? 0;
            if (idx > maxIdx) maxIdx = idx;
          }
          _subirFotoManual('antes', maxIdx + 1);
        },
        icon: const Icon(Icons.add_to_photos),
        label: const Text('AGREGAR NUEVA PAREJA (ANTES)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue.shade700,
          side: BorderSide(color: Colors.blue.shade300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _subirFotoManual(String tipo, int pairIndex) async {
    // Similar a _seleccionarYSubirFoto pero forzando el pairIndex
    // Simplificamos: llamamos a una versión modificada
    _seleccionarYSubirFotoConIndex(tipo, pairIndex);
  }

  // Versión que permite inyectar el pairIndex
  Future<void> _seleccionarYSubirFotoConIndex(String tipo, int pairIndex) async {
    if (!widget.enabled) return;

    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Foto ${tipo.toUpperCase()} (Grupo $pairIndex)'),
        content: const Text('¿Cómo quieres obtener la imagen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ImageSource.gallery), child: const Text('Galería')),
          if (!kIsWeb) TextButton(onPressed: () => Navigator.pop(context, ImageSource.camera), child: const Text('Cámara')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ],
      ),
    );

    if (source == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);

      if (image != null) {
        setState(() => _isUploading = true);
        final exito = await FotosService.subirFoto(widget.servicioId, image, tipo, pairIndex: pairIndex);
        if (exito) {
          await _cargarFotos();
        } else {
          _mostrarError('Error subiendo foto');
        }
      }
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildTabButton(String tipo, String label, IconData icon) {
    final isSelected = _selectedTipo == tipo;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTipo = tipo),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? theme.primaryColor : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? theme.primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
