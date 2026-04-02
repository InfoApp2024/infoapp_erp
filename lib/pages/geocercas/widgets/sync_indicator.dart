import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/async_upload_service.dart';

/// Widget que muestra un indicador visual de sincronización
/// cuando hay uploads pendientes de fotos de geocercas
class SyncIndicator extends StatefulWidget {
  const SyncIndicator({super.key});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator>
    with SingleTickerProviderStateMixin {
  int _pendingCount = 0;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    // Configurar animación de rotación
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Cargar contador inicial
    _updateCount();

    // Escuchar cambios en la cola de uploads
    AsyncUploadService.addListener(_updateCount);
  }

  @override
  void dispose() {
    AsyncUploadService.removeListener(_updateCount);
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _updateCount() async {
    final count = await AsyncUploadService.getPendingCount();
    if (mounted) {
      setState(() {
        _pendingCount = count;

        // Iniciar/detener animación según el estado
        if (_pendingCount > 0) {
          if (!_rotationController.isAnimating) {
            _rotationController.repeat();
          }
        } else {
          _rotationController.stop();
          _rotationController.reset();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // No mostrar nada si no hay uploads pendientes
    if (_pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: _pendingCount == 1
          ? 'Sincronizando 1 foto...'
          : 'Sincronizando $_pendingCount fotos...',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de nube girando
            RotationTransition(
              turns: _rotationController,
              child: Icon(
                PhosphorIcons.cloudArrowUp(),
                size: 20,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 8),
            // Contador
            Text(
              '$_pendingCount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
