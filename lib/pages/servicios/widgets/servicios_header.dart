import 'package:flutter/material.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ServiciosHeader extends StatelessWidget {
  final TextEditingController searchController;
  final String filtroTexto;
  final Function(String) onSearch;
  final VoidCallback onClear;
  final Color primaryColor; // ? NUEVO PARéMETRO

  const ServiciosHeader({
    super.key,
    required this.searchController,
    required this.filtroTexto,
    required this.onSearch,
    required this.onClear,
    required this.primaryColor, // ? NUEVO REQUERIDO
  });

  @override
  Widget build(BuildContext context) {
    // Eliminado uso de Provider para evitar error
    // final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    // final primaryColor = themeProvider.primaryColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: primaryColor, // Usar parámetro recibido
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              key: const ValueKey('servicios_search_field'), // ? Fix para error de Web
              controller: searchController,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: InputDecoration(
                hintText: 'Buscar por orden, equipo, empresa, placa...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 20),
                suffixIcon:
                    filtroTexto.isNotEmpty
                        ? IconButton(
                            icon: Icon(PhosphorIcons.x(), size: 20),
                            onPressed: onClear,
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
