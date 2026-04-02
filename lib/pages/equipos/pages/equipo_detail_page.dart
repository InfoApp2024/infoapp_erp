import 'package:flutter/material.dart';
import 'package:infoapp/pages/equipos/models/equipo_model.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:infoapp/pages/equipos/pages/equipo_form_page.dart';
import 'package:infoapp/pages/equipos/controllers/equipos_controller.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';
import 'package:infoapp/core/enums/modulo_enum.dart';
import 'package:infoapp/pages/equipos/widgets/equipo_detail_info.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';

class EquipoDetailPage extends StatelessWidget {
  final EquipoModel equipo;
  final EquiposController? controller;
  const EquipoDetailPage({super.key, required this.equipo, this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(equipo.nombre ?? 'Equipo')),
            if (equipo.estadoId != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: FutureBuilder<List<EstadoModel>>(
                  future: () async {
                    // Cargar estados de ambos módulos y combinar por ID
                    final deEquipo = await ServiciosApiService.listarEstados(
                      modulo: ModuloEnum.equipos.key,
                    );
                    final deServicio = await ServiciosApiService.listarEstados(
                      modulo: ModuloEnum.servicios.key,
                    );
                    final Map<int, EstadoModel> porId = {
                      for (final e in deEquipo) e.id: e,
                      for (final s in deServicio) s.id: s,
                    };
                    return porId.values.toList();
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    final estados = snapshot.data ?? const <EstadoModel>[];
                    try {
                      final est = estados.firstWhere(
                        (e) => e.id == equipo.estadoId,
                      );
                      return _EstadoChip(
                        nombre: est.nombre,
                        colorHex: est.color,
                      );
                    } catch (_) {
                      final nombre = equipo.estadoNombre;
                      return (nombre != null && nombre.isNotEmpty)
                          ? _EstadoChip(
                            nombre: nombre,
                            colorHex: equipo.estadoColor,
                          )
                          : const SizedBox.shrink();
                    }
                  },
                ),
              ),
            if (equipo.estadoId == null &&
                (equipo.estadoNombre ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: _EstadoChip(
                  nombre: equipo.estadoNombre!,
                  colorHex: equipo.estadoColor,
                ),
              ),
          ],
        ),
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar',
            onPressed: PermissionStore.instance.can('equipos', 'actualizar')
                ? () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => EquipoFormPage(
                        equipo: equipo,
                        controller: controller ?? EquiposController(),
                      ),
                ),
              );
              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Equipo actualizado'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
                : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: EquipoDetailInfo(equipo: equipo),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String nombre;
  final String? colorHex;
  const _EstadoChip({required this.nombre, this.colorHex});

  Color _parseColor(String? hex) {
    final h = (hex ?? '').replaceAll('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    // Colores por defecto según estado
    switch (nombre.toLowerCase()) {
      case 'activo':
        return const Color(0xFF4CAF50);
      case 'en mantenimiento':
        return const Color(0xFFFB8C00);
      case 'en préstamo':
        return const Color(0xFF64B5F6);
      case 'inactivo':
        return const Color(0xFF9E9E9E);
      case 'de baja':
        return const Color(0xFFE57373);
      default:
        return const Color(0xFF607D8B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(colorHex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            nombre,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
