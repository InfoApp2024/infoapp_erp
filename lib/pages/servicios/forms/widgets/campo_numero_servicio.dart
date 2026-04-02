import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget especializado para el campo de número de servicio
class CampoNumeroServicio extends StatelessWidget {
  final TextEditingController controller;
  final bool puedeEditar;
  final VoidCallback? onVerificar;
  final bool soloLectura;

  const CampoNumeroServicio({
    super.key,
    required this.controller,
    required this.puedeEditar,
    this.onVerificar,
    this.soloLectura = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header informativo (solo en creación / cuando puede editar)
        if (puedeEditar) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.edit, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Número de Servicio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Text(
                        '✨ Primer servicio: Puedes editarlo',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (onVerificar != null && !soloLectura)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onVerificar,
                    tooltip: 'Actualizar',
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],

        // Campo de input
        TextFormField(
          controller: controller,
          enabled: puedeEditar && !soloLectura,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6), // Máximo 6 dígitos
          ],
          decoration: InputDecoration(
            labelText: 'Número del Servicio *',
            hintText: puedeEditar ? 'Ingresa el número inicial' : 'Automático',
            prefixIcon: Icon(
              Icons.confirmation_number,
              color:
                  puedeEditar
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            prefixText: '#',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    puedeEditar
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.35)
                        : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    puedeEditar
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                width: 2,
              ),
            ),
            filled: true,
            fillColor:
                puedeEditar && !soloLectura
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El número de servicio es obligatorio';
            }
            final numero = int.tryParse(value.trim());
            if (numero == null || numero <= 0) {
              return 'Debe ser un número mayor a 0';
            }
            if (numero > 999999) {
              return 'Número demasiado grande (máximo 999,999)';
            }
            return null;
          },
        ),

        const SizedBox(height: 12),

        // Información adicional (solo cuando puede editar)
        if (puedeEditar)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Theme.of(context).colorScheme.primary, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ℹ️ Solo puedes editar este número ahora. Los siguientes servicios serán consecutivos automáticos a partir de este valor.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
