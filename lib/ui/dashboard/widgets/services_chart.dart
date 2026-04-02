import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:infoapp/models/dashboard_kpi.dart';

class ServicesPieChart extends StatefulWidget {
  final List<ChartData> data;
  final String title;

  const ServicesPieChart({super.key, required this.data, required this.title});

  @override
  State<ServicesPieChart> createState() => _ServicesPieChartState();
}

class _ServicesPieChartState extends State<ServicesPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(child: Text("No hay datos para mostrar"));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                // Si hay poco espacio horizontal (móvil), usar diseño en columna
                bool isNarrow = constraints.maxWidth < 600;

                if (isNarrow) {
                  return Column(
                    children: [
                      SizedBox(height: 300, child: _buildChart()),
                      const SizedBox(height: 24),
                      _buildLegend(isNarrow),
                    ],
                  );
                } else {
                  // Diseño horizontal para tablet/web
                  return SizedBox(
                    height: 320,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: _buildChart()),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: _buildLegend(isNarrow),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                touchedIndex = -1;
                return;
              }
              touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: showingSections(),
      ),
    );
  }

  Widget _buildLegend(bool isNarrow) {
    if (isNarrow) {
      // Diseño de leyenda en grid para móvil (debajo del gráfico)
      return Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children:
            widget.data.map((item) {
              final color = _getColor(item.colorHex, item.label);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, color: color),
                  const SizedBox(width: 8),
                  Text(
                    '${item.label} (${item.value.toInt()})',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              );
            }).toList(),
      );
    }

    // Diseño de lista vertical para desktop (al lado)
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          widget.data.map((item) {
            final color = _getColor(item.colorHex, item.label);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Container(width: 12, height: 12, color: color),
                  const SizedBox(width: 8),
                  Text(
                    '${item.label} (${item.value.toInt()})',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  List<PieChartSectionData> showingSections() {
    return List.generate(widget.data.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 22.0 : 16.0;
      final radius =
          isTouched ? 90.0 : 80.0; // Aumentado significativamente el tamaño
      final item = widget.data[i];
      final color = _getColor(item.colorHex, item.label);

      return PieChartSectionData(
        color: color,
        value: item.value,
        title: '${item.value.toInt()}',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
        // Agregar borde para resaltar selección
        badgeWidget: isTouched ? _buildBadge(item.label) : null,
        badgePositionPercentageOffset: .98,
      );
    });
  }

  // Widget para mostrar etiqueta al tocar
  Widget _buildBadge(String text) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Color _getColor(String? hex, String label) {
    if (hex != null && hex.isNotEmpty) {
      try {
        return Color(int.parse(hex.replaceAll('#', '0xFF')));
      } catch (_) {}
    }
    // Fallback colors based on label or hash
    if (label.toLowerCase().contains('final')) return Colors.green;
    if (label.toLowerCase().contains('proceso')) return Colors.orange;
    if (label.toLowerCase().contains('pend')) return Colors.red;
    return Colors.primaries[label.hashCode % Colors.primaries.length];
  }
}
