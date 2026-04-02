import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';

/// Painter para mostrar línea temporal durante creación de conexión
class TemporaryConnectionPainter extends CustomPainter {
  final Offset? startPosition;
  final Offset? endPosition;

  const TemporaryConnectionPainter({
    this.startPosition,
    this.endPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (startPosition == null || endPosition == null) return;

    final paint = Paint()
      ..color = WorkflowTheme.primaryPurple.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Línea punteada
    final dashPaint = Paint()
      ..color = WorkflowTheme.primaryPurple.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    _drawDashedLine(canvas, startPosition!, endPosition!, dashPaint);

    // Círculo en el punto final
    canvas.drawCircle(
      endPosition!,
      6,
      Paint()
        ..color = WorkflowTheme.primaryPurple
        ..style = PaintingStyle.fill,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 4.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final unitX = dx / distance;
    final unitY = dy / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final dashEnd = currentDistance + dashWidth;
      final x1 = start.dx + unitX * currentDistance;
      final y1 = start.dy + unitY * currentDistance;
      final x2 = start.dx + unitX * (dashEnd > distance ? distance : dashEnd);
      final y2 = start.dy + unitY * (dashEnd > distance ? distance : dashEnd);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(TemporaryConnectionPainter oldDelegate) {
    return oldDelegate.startPosition != startPosition ||
        oldDelegate.endPosition != endPosition;
  }
}
