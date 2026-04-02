import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ServiciosEmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isFiltering;

  const ServiciosEmptyState({
    super.key,
    required this.onRefresh,
    this.isFiltering = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Icon(
              isFiltering
                ? PhosphorIcons.magnifyingGlass()
                : PhosphorIcons.archive(),
              size: 80,
              color: Colors.grey.shade400,
            ),
          const SizedBox(height: 16),
          Text(
            'No hay servicios registrados',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el boté³n + para agregar uno',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          // if (onNuevoServicio != null) ...[ // Removido por error de definicié³n
          /* 
          if (isFiltering == false) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {}, // TODO: Implementar
              icon: const Icon(Icons.add),
              label: const Text('Crear Primer Servicio'),
            ),
          ],
          */
        ],
      ),
    );
  }
}
