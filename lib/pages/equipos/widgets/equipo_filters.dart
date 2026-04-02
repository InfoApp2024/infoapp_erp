import 'package:flutter/material.dart';

class EquipoFilters extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const EquipoFilters({
    super.key,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Buscar por nombre, marca, modelo, placa...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
