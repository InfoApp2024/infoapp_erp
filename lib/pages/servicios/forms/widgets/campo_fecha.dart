import 'package:flutter/material.dart';

class CampoFecha extends StatelessWidget {
  final String label;
  final DateTime? fechaSeleccionada;
  final Function(DateTime) onFechaSeleccionada;
  final String? errorText;
  final bool obligatorio;

  const CampoFecha({
    super.key,
    required this.label,
    this.fechaSeleccionada,
    required this.onFechaSeleccionada,
    this.errorText,
    this.obligatorio = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (obligatorio) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: errorText != null ? Colors.red : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              Icons.calendar_today,
              color: Theme.of(context).primaryColor,
            ),
            title: Text(
              fechaSeleccionada != null
                  ? '${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}'
                  : 'Seleccionar fecha',
              style: TextStyle(
                color:
                    fechaSeleccionada != null
                        ? Colors.black87
                        : Colors.grey.shade600,
              ),
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _seleccionarFecha(context),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onFechaSeleccionada(picked);
    }
  }
}
