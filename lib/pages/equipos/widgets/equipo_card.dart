import 'package:flutter/material.dart';
import 'package:infoapp/pages/equipos/models/equipo_model.dart';

class EquipoCard extends StatelessWidget {
  final EquipoModel equipo;
  final VoidCallback? onTap;
  const EquipoCard({super.key, required this.equipo, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(equipo.nombre ?? 'Equipo'),
        subtitle: Text('${equipo.marca ?? '-'} • ${equipo.modelo ?? '-'}'),
        trailing: Text(equipo.placa ?? ''),
        onTap: onTap,
      ),
    );
  }
}
