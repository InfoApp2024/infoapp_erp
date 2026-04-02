import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';
import 'package:infoapp/core/branding/branding_colors.dart';

/// Widget para filtrar y buscar servicios
class ServiciosFiltros extends StatefulWidget {
  final Function(String) onFiltroChanged;
  final int totalServicios;
  final int serviciosFiltrados;

  const ServiciosFiltros({
    super.key,
    required this.onFiltroChanged,
    required this.totalServicios,
    required this.serviciosFiltrados,
  });

  @override
  State<ServiciosFiltros> createState() => _ServiciosFiltrosState();
}

class _ServiciosFiltrosState extends State<ServiciosFiltros> {
  final TextEditingController _filtroController = TextEditingController();
  bool _mostrarFiltrosAvanzados = false;

  @override
  void dispose() {
    _filtroController.dispose();
    super.dispose();
  }

  void _limpiarFiltro() {
    _filtroController.clear();
    widget.onFiltroChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          // Header con estadísticas
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.funnel(),
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtros de Búsqueda',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Encuentra servicios rápidamente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge con contador
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${widget.serviciosFiltrados}/${widget.totalServicios}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido de filtros
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Campo de búsqueda principal
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: TextField(
                          controller: _filtroController,
                          inputFormatters: [UpperCaseTextFormatter()],
                          decoration: InputDecoration(
                            hintText: 'Buscar por orden, equipo, empresa...',
                            hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              PhosphorIcons.magnifyingGlass(),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            suffixIcon:
                                _filtroController.text.isNotEmpty
                                    ? IconButton(
                                      icon: Icon(
                                        PhosphorIcons.x(),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                      onPressed: _limpiarFiltro,
                                    )
                                    : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {});
                            widget.onFiltroChanged(value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Botón filtros avanzados
                    Container(
                      decoration: BoxDecoration(
                        color: _mostrarFiltrosAvanzados
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _mostrarFiltrosAvanzados
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          PhosphorIcons.sliders(),
                          color: _mostrarFiltrosAvanzados
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _mostrarFiltrosAvanzados =
                                !_mostrarFiltrosAvanzados;
                          });
                        },
                        tooltip: 'Filtros avanzados',
                      ),
                    ),
                  ],
                ),

                // Filtros avanzados (expandible)
                if (_mostrarFiltrosAvanzados) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.gear(),
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Filtros Avanzados',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Aquí puedes agregar más filtros específicos
                        Row(
                          children: [
                            Expanded(
                              child: _buildFiltroChip(
                                'Preventivo',
                                PhosphorIcons.clock(),
                                context.successColor,
                                false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFiltroChip(
                                'Correctivo',
                                PhosphorIcons.wrench(),
                                Theme.of(context).colorScheme.error,
                                false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFiltroChip(
                                'Predictivo',
                                PhosphorIcons.chartBar(),
                                Theme.of(context).colorScheme.primary,
                                false,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Botón limpiar filtros
                        Center(
                          child: TextButton.icon(
                            icon: Icon(PhosphorIcons.broom(), size: 16),
                            label: const Text('Limpiar todos los filtros'),
                            onPressed: _limpiarFiltro,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Información de resultados
                if (_filtroController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.serviciosFiltrados > 0
                          ? context.successColor.withOpacity(0.08)
                          : context.warningColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.serviciosFiltrados > 0
                            ? context.successColor.withOpacity(0.3)
                            : context.warningColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.serviciosFiltrados > 0
                              ? PhosphorIcons.checkCircle()
                              : PhosphorIcons.info(),
                          color: widget.serviciosFiltrados > 0
                              ? context.successColor
                              : context.warningColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.serviciosFiltrados > 0
                                ? 'Se encontraron ${widget.serviciosFiltrados} servicios que coinciden con "${_filtroController.text}"'
                                : 'No se encontraron servicios con "${_filtroController.text}". Intenta con términos diferentes.',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.serviciosFiltrados > 0
                                  ? context.successColor
                                  : context.warningColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        // Aquí implementar la lógica de filtro específico
        widget.onFiltroChanged(label.toLowerCase());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
