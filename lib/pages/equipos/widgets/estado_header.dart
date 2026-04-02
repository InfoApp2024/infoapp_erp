import 'package:flutter/material.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';

class EstadoHeader extends StatelessWidget {
  final EstadoModel estActual;
  final EstadoModel? siguienteEstado;
  final bool isChanging;
  final VoidCallback? onAdvance;
  final Color branding;

  const EstadoHeader({
    super.key,
    required this.estActual,
    required this.siguienteEstado,
    required this.isChanging,
    required this.onAdvance,
    required this.branding,
  });

  Color _parseColor(String? colorStr, String nombre) {
    try {
      if (colorStr == null || colorStr.isEmpty) {
        switch (nombre.toLowerCase()) {
          case 'registrado':
            return Colors.blueGrey;
          case 'en atención':
            return Colors.orange;
          case 'atendido':
            return Colors.green;
          default:
            return Colors.blueGrey;
        }
      }
      String c = colorStr.replaceAll('#', '').trim();
      if (c.length == 6) c = 'ff$c';
      final value = int.parse(c, radix: 16);
      return Color(value);
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorActual = _parseColor(estActual.color, estActual.nombre);
    final colorSiguiente = _parseColor(siguienteEstado?.color, siguienteEstado?.nombre ?? '');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: branding.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorActual.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorActual.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colorActual, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(estActual.nombre),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (siguienteEstado != null)
              ElevatedButton.icon(
                onPressed: isChanging ? null : onAdvance,
                icon: isChanging
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 16),
                label: Text(isChanging ? 'Cambiando...' : 'Avanzar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorSiguiente,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
