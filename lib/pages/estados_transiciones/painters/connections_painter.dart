import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';

/// CustomPainter que dibuja las conexiones entre nodos usando curvas de Bézier suaves
class ConnectionsPainter extends CustomPainter {
  final List<Map<String, dynamic>> transiciones;
  final Map<String, Offset> nodePositions;
  final String? selectedTransitionId;
  final double nodeWidth;
  final double nodeHeight;

  const ConnectionsPainter({
    required this.transiciones,
    required this.nodePositions,
    this.selectedTransitionId,
    this.nodeWidth = 180.0,
    this.nodeHeight = 80.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final transicion in transiciones) {
      final origenId = transicion['estado_origen_id']?.toString();
      final destinoId = transicion['estado_destino_id']?.toString();
      final transicionId = transicion['id']?.toString();
      final label = transicion['nombre'] ?? '';

      if (origenId == null || destinoId == null) continue;

      final origenPos = nodePositions[origenId];
      final destinoPos = nodePositions[destinoId];

      if (origenPos == null || destinoPos == null) continue;

      final isSelected = transicionId == selectedTransitionId;

      _drawConnection(
        canvas,
        origenPos,
        destinoPos,
        label,
        isSelected,
      );
    }
  }

  /// Dibuja una conexión individual con curva de Bézier cúbica
  void _drawConnection(
    Canvas canvas,
    Offset start,
    Offset end,
    String label,
    bool isSelected,
  ) {
    // Calcular puntos de conexión en los bordes de los nodos
    final startPoint = _getConnectionPoint(start, end, nodeWidth, nodeHeight);
    final endPoint = _getConnectionPoint(end, start, nodeWidth, nodeHeight);

    // Calcular puntos de control para curva de Bézier CÚBICA (más suave)
    final dx = endPoint.dx - startPoint.dx;
    final dy = endPoint.dy - startPoint.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Dos puntos de control para curva cúbica
    final curvature = math.min(distance * 0.3, 100.0);
    
    final controlPoint1 = Offset(
      startPoint.dx + dx * 0.25,
      startPoint.dy - curvature,
    );
    
    final controlPoint2 = Offset(
      startPoint.dx + dx * 0.75,
      endPoint.dy - curvature,
    );

    // Crear path con curva de Bézier CÚBICA
    final path = Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        endPoint.dx,
        endPoint.dy,
      );

    // Pintar la línea
    final linePaint = Paint()
      ..color = isSelected
          ? WorkflowTheme.primaryPurple
          : WorkflowTheme.textSecondary.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3.0 : 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Dibujar punta de flecha
    final midPoint = Offset(
      (controlPoint1.dx + controlPoint2.dx) / 2,
      (controlPoint1.dy + controlPoint2.dy) / 2,
    );
    _drawArrowHead(canvas, midPoint, endPoint, linePaint.color);

    // Dibujar etiqueta en el punto medio si existe
    if (label.isNotEmpty) {
      _drawLabel(canvas, midPoint, label, isSelected);
    }
  }

  /// Calcula el punto de conexión en el borde del nodo
  Offset _getConnectionPoint(
    Offset nodeCenter,
    Offset targetCenter,
    double width,
    double height,
  ) {
    final dx = targetCenter.dx - nodeCenter.dx;
    final dy = targetCenter.dy - nodeCenter.dy;

    if (dx == 0 && dy == 0) return nodeCenter;

    final angle = math.atan2(dy, dx);

    // Calcular intersección con el rectángulo del nodo
    final halfWidth = width / 2;
    final halfHeight = height / 2;

    double x, y;

    if (dx.abs() / halfWidth > dy.abs() / halfHeight) {
      // Intersección con lado izquierdo o derecho
      x = nodeCenter.dx + (dx > 0 ? halfWidth : -halfWidth);
      y = nodeCenter.dy + (x - nodeCenter.dx) * math.tan(angle);
    } else {
      // Intersección con lado superior o inferior
      y = nodeCenter.dy + (dy > 0 ? halfHeight : -halfHeight);
      x = nodeCenter.dx + (y - nodeCenter.dy) / math.tan(angle);
    }

    return Offset(x, y);
  }

  /// Dibuja la punta de flecha al final de la conexión
  void _drawArrowHead(Canvas canvas, Offset control, Offset end, Color color) {
    final dx = end.dx - control.dx;
    final dy = end.dy - control.dy;
    final angle = math.atan2(dy, dx);

    const arrowSize = 12.0;
    const arrowAngle = math.pi / 6; // 30 grados

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle - arrowAngle),
        end.dy - arrowSize * math.sin(angle - arrowAngle),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle + arrowAngle),
        end.dy - arrowSize * math.sin(angle + arrowAngle),
      );

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, arrowPaint);
  }

  /// Dibuja la etiqueta de la transición en el punto medio de la curva
  void _drawLabel(Canvas canvas, Offset position, String label, bool isSelected) {
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: isSelected ? WorkflowTheme.primaryPurple : WorkflowTheme.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        backgroundColor: Colors.white.withOpacity(0.95),
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Dibujar fondo con padding
    final padding = 6.0;
    final rect = Rect.fromCenter(
      center: position,
      width: textPainter.width + padding * 2,
      height: textPainter.height + padding * 2,
    );

    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isSelected
          ? WorkflowTheme.primaryPurple.withOpacity(0.3)
          : WorkflowTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );

    // Dibujar texto
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(ConnectionsPainter oldDelegate) {
    return oldDelegate.transiciones != transiciones ||
        oldDelegate.nodePositions != nodePositions ||
        oldDelegate.selectedTransitionId != selectedTransitionId;
  }
}
