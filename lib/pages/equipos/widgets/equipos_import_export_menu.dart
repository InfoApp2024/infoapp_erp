import 'package:flutter/material.dart';

class EquiposImportExportMenu extends StatelessWidget {
  final VoidCallback? onTemplate;
  final VoidCallback? onExport;
  final VoidCallback? onImport;
  final VoidCallback? onRefresh;

  const EquiposImportExportMenu({
    super.key,
    this.onTemplate,
    this.onExport,
    this.onImport,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'template':
            onTemplate?.call();
            break;
          case 'export':
            onExport?.call();
            break;
          case 'import':
            onImport?.call();
            break;
          case 'refresh':
            onRefresh?.call();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'template',
          child: Row(
            children: [
              Icon(Icons.description),
              SizedBox(width: 8),
              Text('Descargar plantilla (Excel)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.grid_on),
              SizedBox(width: 8),
              Text('Exportar equipos (Excel)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.upload_file),
              SizedBox(width: 8),
              Text('Importar equipos (Excel)'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh),
              SizedBox(width: 8),
              Text('Refrescar lista'),
            ],
          ),
        ),
      ],
    );
  }
}
