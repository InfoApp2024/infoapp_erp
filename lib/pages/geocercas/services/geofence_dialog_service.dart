import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import '../controllers/geocercas_controller.dart';

/// Servicio global para mostrar diálogos de evidencia de geocercas
/// desde cualquier parte de la aplicación
class GeofenceDialogService {
  static OverlayEntry? _currentOverlay;
  static bool _isDialogShowing = false;

  /// Muestra el diálogo de captura de evidencia fotográfica
  static void showEvidenceDialog({
    required BuildContext context,
    required PendingTransition transition,
    required Future<bool> Function(File photo) onPhotoTaken,
  }) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    // Remover overlay anterior si existe
    _currentOverlay?.remove();
    _currentOverlay = null;

    // Crear nuevo overlay
    _currentOverlay = OverlayEntry(
      builder: (overlayContext) => Material(
        color: Colors.black54,
        child: Center(
          child: _EvidenceDialogContent(
            transition: transition,
            onPhotoTaken: onPhotoTaken,
            onDismiss: () {
              _currentOverlay?.remove();
              _currentOverlay = null;
              _isDialogShowing = false;
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// Cierra el diálogo actual si existe
  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _isDialogShowing = false;
  }
}

/// Widget interno del contenido del diálogo
class _EvidenceDialogContent extends StatelessWidget {
  final PendingTransition transition;
  final Future<bool> Function(File photo) onPhotoTaken;
  final VoidCallback onDismiss;

  const _EvidenceDialogContent({
    required this.transition,
    required this.onPhotoTaken,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final branding = BrandingService();
    final isEntry = transition.event == GeofenceEvent.ingreso;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Text(
            isEntry ? 'Confirmar Entrada' : 'Confirmar Salida',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Icono
          Icon(
            isEntry ? Icons.login : Icons.logout,
            size: 64,
            color: isEntry ? Colors.green : Colors.red,
          ),
          
          const SizedBox(height: 16),
          
          // Mensaje
          Text(
            'Se ha detectado tu presencia en: ${transition.geocerca.nombre}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            'Es obligatorio capturar una fotografía como evidencia para proceder con el registro.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          
          const SizedBox(height: 24),
          
          // Botón de captura
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Tomar Fotografía'),
              style: ElevatedButton.styleFrom(
                backgroundColor: branding.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final ImagePicker picker = ImagePicker();
                
                try {
                  final XFile? photo = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );

                  if (photo != null) {
                    // Guardar el contexto del overlay antes de operaciones async
                    final overlayContext = context;
                    
                    // Mostrar indicador de carga
                    showDialog(
                      context: overlayContext,
                      barrierDismissible: false,
                      builder: (_) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    bool success = false;
                    try {
                      // ✅ Envolver en try-catch para capturar errores
                      success = await onPhotoTaken(File(photo.path));
                    } catch (e) {
                      debugPrint('❌ Error en onPhotoTaken: $e');
                      success = false;
                    }
                    
                    // Cerrar indicador de carga
                    if (overlayContext.mounted) {
                      Navigator.of(overlayContext).pop();
                    }
                    
                    // ✅ SIEMPRE cerrar el diálogo de evidencia (incluso si hay error)
                    onDismiss();
                    
                    // Mostrar resultado
                    if (overlayContext.mounted) {
                      ScaffoldMessenger.of(overlayContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            success 
                              ? 'Registro confirmado exitosamente'
                              : 'Error al procesar el registro',
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('❌ Error al capturar foto: $e');
                  
                  // ✅ Cerrar diálogo incluso si hay error en la cámara
                  onDismiss();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al abrir la cámara: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
