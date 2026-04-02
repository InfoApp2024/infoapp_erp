import 'package:flutter/material.dart';

/// CustomPainter que dibuja una rejilla de fondo para ayudar con la alineación visual
/// de nodos en el diagrama de workflow
class GridBackgroundPainter extends CustomPainter {
  final double spacing;
  final Color gridColor;
  final double strokeWidth;
  final bool showDots; // true = puntos, false = líneas

  const GridBackgroundPainter({
    this.spacing = 50.0,
    this.gridColor = const Color(0xFFE5E7EB),
    this.strokeWidth = 1.0,
    this.showDots = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..strokeWidth = strokeWidth
      ..style = showDots ? PaintingStyle.fill : PaintingStyle.stroke;

    if (showDots) {
      // Dibujar puntos en intersecciones
      for (double x = 0; x < size.width; x += spacing) {
        for (double y = 0; y < size.height; y += spacing) {
          canvas.drawCircle(Offset(x, y), 1.5, paint);
        }
      }
    } else {
      // Dibujar líneas verticales
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          paint,
        );
      }

      // Dibujar líneas horizontales
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(GridBackgroundPainter oldDelegate) {
    return oldDelegate.spacing != spacing ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showDots != showDots;
  }
}
