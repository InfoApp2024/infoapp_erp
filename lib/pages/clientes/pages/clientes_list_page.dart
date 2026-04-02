import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/pages/clientes/controllers/clientes_controller.dart';
import 'package:infoapp/pages/clientes/pages/cliente_form_page.dart';
import 'package:infoapp/pages/clientes/widgets/cliente_card.dart';
import 'package:infoapp/pages/clientes/pages/impuestos_manager_dialog.dart';

class ClientesListPage extends StatelessWidget {
  const ClientesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ClientesController()..cargarClientes(),
      child: const _ClientesListView(),
    );
  }
}

class _ClientesListView extends StatelessWidget {
  const _ClientesListView();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ClientesController>(context);
    final theme = Theme.of(context);

    // 1. Permiso de VER - Gatekeeper para acceso al módulo
    final bool canView = PermissionStore.instance.can('clientes', 'ver');
    if (!canView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Clientes'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tienes permiso para acceder al módulo de clientes',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 2. Permisos específicos
    final bool canList = PermissionStore.instance.can('clientes', 'listar');
    final bool canCreate = PermissionStore.instance.can('clientes', 'crear');
    final bool canUpdate = PermissionStore.instance.can('clientes', 'actualizar');
    final bool canDelete = PermissionStore.instance.can('clientes', 'eliminar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'Configurar Impuestos',
            onPressed: canUpdate ? () {
              showDialog(
                context: context,
                builder: (_) => const ImpuestosManagerDialog(),
              );
            } : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: canList ? () => controller.cargarClientes() : null,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear Cliente',
            onPressed: canCreate ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ClienteFormPage()),
              ).then((changed) {
                if (changed == true) {
                  controller.cargarClientes();
                }
              });
            } : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, NIT, email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                // Debounce simple o búsqueda directa
                controller.setQuery(val);
              },
            ),
          ),

          // Lista
          Expanded(
            child:
                !canList
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No tienes permiso para listar clientes',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : controller.loading
                    ? const Center(child: CircularProgressIndicator())
                    : controller.clientes.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron clientes',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: controller.clientes.length,
                      itemBuilder: (context, index) {
                        final cliente = controller.clientes[index];
                        return ClienteCard(
                          cliente: cliente,
                          onTap: () {
                            if (!canUpdate) return;
                            // Ir a detalle (opcional) o editar
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        ClienteFormPage(cliente: cliente),
                              ),
                            ).then((changed) {
                              if (changed == true) {
                                controller.cargarClientes();
                              }
                            });
                          },
                          onEdit: canUpdate ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        ClienteFormPage(cliente: cliente),
                              ),
                            ).then((changed) {
                              if (changed == true) {
                                controller.cargarClientes();
                              }
                            });
                          } : null,
                          onDelete: canDelete ? () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Confirmar eliminación'),
                                    content: const Text(
                                      '¿Está seguro de desactivar este cliente?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: const Text(
                                          'Desactivar',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirm == true && cliente.id != null) {
                              final success = await controller.eliminarCliente(
                                cliente.id!,
                              );
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cliente desactivado'),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Error al desactivar cliente',
                                    ),
                                  ),
                                );
                              }
                            }
                          } : null,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
