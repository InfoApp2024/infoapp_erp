import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../inspecciones/models/sistema_model.dart';
import '../../inspecciones/providers/sistemas_provider.dart';
import '../widgets/sistema_crud_modal.dart';

class SistemasListPage extends StatefulWidget {
  const SistemasListPage({super.key});

  @override
  State<SistemasListPage> createState() => _SistemasListPageState();
}

class _SistemasListPageState extends State<SistemasListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SistemasProvider>().cargarSistemas();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            // Header
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 500;
                return Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Icon(
                            PhosphorIcons.gear(),
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gestión de Sistemas',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Administra los sistemas asociados',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (!isSmall) ...[
                          ElevatedButton.icon(
                            onPressed: () => _mostrarModalCrud(context),
                            icon: Icon(PhosphorIcons.plus(), size: 18),
                            label: const Text('Nuevo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(PhosphorIcons.x()),
                          ),
                        ] else
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(PhosphorIcons.x()),
                          ),
                      ],
                    ),
                    if (isSmall) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _mostrarModalCrud(context),
                          icon: Icon(PhosphorIcons.plus(), size: 18),
                          label: const Text('Nuevo Sistema'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Buscador
            TextField(
              controller: _searchController,
              onChanged:
                  (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar sistema...',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tabla
            Expanded(
              child: Consumer<SistemasProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.sistemas.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final filtered =
                      provider.sistemas.where((s) {
                        final nombre = (s.nombre ?? '').toLowerCase();
                        final desc = (s.descripcion ?? '').toLowerCase();
                        return nombre.contains(_searchQuery) ||
                            desc.contains(_searchQuery);
                      }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No hay sistemas creados'
                            : 'No se encontraron resultados',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            Colors.grey[50],
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Sistema',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Descripción',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Estado',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Acciones',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows:
                              filtered.map((sistema) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        sistema.nombre ?? 'N/A',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 300,
                                        child: Text(
                                          sistema.descripcion ?? '-',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      _buildStatusChip(sistema.activo ?? true),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              PhosphorIcons.pencilSimple(),
                                              size: 18,
                                              color: Colors.orange,
                                            ),
                                            onPressed:
                                                () => _mostrarModalCrud(
                                                  context,
                                                  sistema: sistema,
                                                ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              PhosphorIcons.trash(),
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                            onPressed:
                                                () => _confirmarEliminar(
                                                  context,
                                                  sistema,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool activo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (activo ? Colors.green : Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (activo ? Colors.green : Colors.grey).withOpacity(0.3),
        ),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: activo ? Colors.green[700] : Colors.grey[700],
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _mostrarModalCrud(BuildContext context, {SistemaModel? sistema}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SistemaCrudModal(sistema: sistema),
    );
  }

  void _confirmarEliminar(BuildContext context, SistemaModel sistema) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar Sistema'),
            content: Text(
              '¿Está seguro de eliminar el sistema "${sistema.nombre}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await context
                      .read<SistemasProvider>()
                      .eliminarSistema(sistema.id!);
                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sistema eliminado'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al eliminar'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }
}
