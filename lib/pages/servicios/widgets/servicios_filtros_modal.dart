import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ServiciosFiltrosModal extends StatefulWidget {
  final List<String> estadosDisponibles;
  final List<String> tiposDisponibles;
  final String? filtroEstadoActual;
  final String? filtroTipoActual;
  final Function(String? estado, String? tipo) onFiltrosChanged;
  final Color primaryColor; // ✅ NUEVO PARÁMETRO

  const ServiciosFiltrosModal({
    super.key,
    required this.estadosDisponibles,
    required this.tiposDisponibles,
    required this.filtroEstadoActual,
    required this.filtroTipoActual,
    required this.onFiltrosChanged,
    required this.primaryColor, // ✅ NUEVO REQUERIDO
  });

  @override
  State<ServiciosFiltrosModal> createState() => _ServiciosFiltrosModalState();
}

class _ServiciosFiltrosModalState extends State<ServiciosFiltrosModal> {
  String? _estadoSeleccionado;
  String? _tipoSeleccionado;

  @override
  void initState() {
    super.initState();
    _estadoSeleccionado = widget.filtroEstadoActual;
    _tipoSeleccionado = widget.filtroTipoActual;
  }

  void _aplicarCambios(String? nuevoEstado, String? nuevoTipo) {
    setState(() {
      _estadoSeleccionado = nuevoEstado;
      _tipoSeleccionado = nuevoTipo;
    });
    widget.onFiltrosChanged(_estadoSeleccionado, _tipoSeleccionado);
  }

  /// Obtener ícono para tipo de mantenimiento (Helper local)
  IconData _getIconoTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'preventivo':
        return PhosphorIcons.clock();
      case 'correctivo':
        return PhosphorIcons.wrench();
      case 'predictivo':
        return PhosphorIcons.chartLineUp();
      case 'emergencia':
        return PhosphorIcons.warningCircle();
      default:
        return PhosphorIcons.gear();
    }
  }

  /// Obtener color para tipo de mantenimiento (Helper local)
  Color _getColorTipo(BuildContext context, String tipo) {
    switch (tipo.toLowerCase()) {
      case 'preventivo':
        return Colors.green;
      case 'correctivo':
        return Colors.red;
      case 'predictivo':
        return widget.primaryColor; // ✅ Usar parámetro
      case 'emergencia':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = widget.primaryColor; // ✅ Usar parámetro

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(PhosphorIcons.funnel(), color: primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Filtros',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(PhosphorIcons.broom()),
                onPressed: () {
                  _aplicarCambios(null, null);
                  Navigator.pop(context);
                },
                tooltip: 'Limpiar todos los filtros',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filtro por estado
          if (widget.estadosDisponibles.isNotEmpty) ...[
            const Text(
              'Estado:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _estadoSeleccionado == null,
                  selectedColor: primaryColor.withOpacity(0.2),
                  checkmarkColor: primaryColor,
                  onSelected: (selected) {
                    _aplicarCambios(null, _tipoSeleccionado);
                  },
                ),
                ...widget.estadosDisponibles.map((estado) {
                  return FilterChip(
                    label: Text(estado),
                    selected: _estadoSeleccionado == estado,
                    selectedColor: primaryColor.withOpacity(0.2),
                    checkmarkColor: primaryColor,
                    onSelected: (selected) {
                      _aplicarCambios(
                        selected ? estado : null,
                        _tipoSeleccionado,
                      );
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Filtro por tipo
          if (widget.tiposDisponibles.isNotEmpty) ...[
            const Text(
              'Tipo de Mantenimiento:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _tipoSeleccionado == null,
                  selectedColor: primaryColor.withOpacity(0.2),
                  checkmarkColor: primaryColor,
                  onSelected: (selected) {
                    _aplicarCambios(_estadoSeleccionado, null);
                  },
                ),
                ...widget.tiposDisponibles.map((tipo) {
                  final color = _getColorTipo(context, tipo);
                  final icono = _getIconoTipo(tipo);

                  return FilterChip(
                    avatar: Icon(
                      icono,
                      size: 16,
                      color: _tipoSeleccionado == tipo ? Colors.white : color,
                    ),
                    label: Text(tipo),
                    selected: _tipoSeleccionado == tipo,
                    selectedColor: color,
                    onSelected: (selected) {
                      _aplicarCambios(
                        _estadoSeleccionado,
                        selected ? tipo : null,
                      );
                    },
                  );
                }),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Resumen de filtros activos
          if (_estadoSeleccionado != null || _tipoSeleccionado != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtros activos:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_estadoSeleccionado != null)
                    Text('• Estado: $_estadoSeleccionado'),
                  if (_tipoSeleccionado != null)
                    Text('• Tipo: $_tipoSeleccionado'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
