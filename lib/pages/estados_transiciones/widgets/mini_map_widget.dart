import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';

/// Mini-mapa que muestra una vista general del diagrama completo
/// y permite navegación rápida
class MiniMapWidget extends StatelessWidget {
  final Size canvasSize;
  final List<Map<String, dynamic>> estados;
  final Map<String, Offset> nodePositions;
  final Matrix4 currentTransform;
  final Function(Offset) onNavigate;
  final double width;
  final double height;

  const MiniMapWidget({
    super.key,
    required this.canvasSize,
    required this.estados,
    required this.nodePositions,
    required this.currentTransform,
    required this.onNavigate,
    this.width = 180,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WorkflowTheme.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: GestureDetector(
          onTapDown: (details) {
            _handleTap(details.localPosition);
          },
          child: CustomPaint(
            size: Size(width, height),
            painter: _MiniMapPainter(
              canvasSize: canvasSize,
              estados: estados,
              nodePositions: nodePositions,
              currentTransform: currentTransform,
              miniMapSize: Size(width, height),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(Offset localPosition) {
    // Convertir posición del mini-mapa a coordenadas del canvas
    final scaleX = canvasSize.width / width;
    final scaleY = canvasSize.height / height;
    
    final canvasPosition = Offset(
      localPosition.dx * scaleX,
      localPosition.dy * scaleY,
    );
    
    onNavigate(canvasPosition);
  }
}

class _MiniMapPainter extends CustomPainter {
  final Size canvasSize;
  final List<Map<String, dynamic>> estados;
  final Map<String, Offset> nodePositions;
  final Matrix4 currentTransform;
  final Size miniMapSize;

  _MiniMapPainter({
    required this.canvasSize,
    required this.estados,
    required this.nodePositions,
    required this.currentTransform,
    required this.miniMapSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo
    final bgPaint = Paint()..color = const Color(0xFFF9FAFB);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Calcular escala
    final scaleX = size.width / canvasSize.width;
    final scaleY = size.height / canvasSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Dibujar nodos
    final nodePaint = Paint()
      ..color = WorkflowTheme.primaryPurple.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (final estado in estados) {
      final id = estado['id'].toString();
      final position = nodePositions[id];
      if (position == null) continue;

      final miniPos = Offset(
        position.dx * scale,
        position.dy * scale,
      );

      canvas.drawCircle(miniPos, 3, nodePaint);
    }

    // Dibujar viewport actual
    _drawViewport(canvas, size, scale);
  }

  void _drawViewport(Canvas canvas, Size size, double scale) {
    // Extraer transformación actual
    final translation = currentTransform.getTranslation();
    final currentScale = currentTransform.getMaxScaleOnAxis();

    // Calcular tamaño del viewport en coordenadas del canvas
    final viewportWidth = size.width / scale / currentScale;
    final viewportHeight = size.height / scale / currentScale;

    // Calcular posición del viewport
    final viewportX = (-translation.x / currentScale) * scale;
    final viewportY = (-translation.y / currentScale) * scale;

    final viewportRect = Rect.fromLTWH(
      viewportX,
      viewportY,
      viewportWidth * scale,
      viewportHeight * scale,
    );

    // Dibujar rectángulo del viewport
    final viewportPaint = Paint()
      ..color = WorkflowTheme.primaryPurple.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final viewportBorderPaint = Paint()
      ..color = WorkflowTheme.primaryPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(viewportRect, viewportPaint);
    canvas.drawRect(viewportRect, viewportBorderPaint);
  }

  @override
  bool shouldRepaint(_MiniMapPainter oldDelegate) {
    return oldDelegate.estados != estados ||
        oldDelegate.nodePositions != nodePositions ||
        oldDelegate.currentTransform != currentTransform;
  }
}
