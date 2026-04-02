import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plantilla_provider.dart';

class ClienteSelectorWidget extends StatefulWidget {
  final int? selectedClienteId;
  final String? fallbackName;
  final Function(int?) onClienteSelected;

  const ClienteSelectorWidget({
    super.key,
    required this.selectedClienteId,
    this.fallbackName,
    required this.onClienteSelected,
  });

  @override
  State<ClienteSelectorWidget> createState() => _ClienteSelectorWidgetState();
}

class _ClienteSelectorWidgetState extends State<ClienteSelectorWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchClientes(String query) {
    setState(() {
      _searchQuery = query;
    });

    final provider = context.read<PlantillaProvider>();
    provider.loadClientes(busqueda: query.isEmpty ? null : query);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlantillaProvider>(
      builder: (context, provider, child) {
        final selectedCliente =
            widget.selectedClienteId != null
                ? provider.getClienteById(widget.selectedClienteId!)
                : null;

        return Card(
          child: ListTile(
            leading: const Icon(Icons.business),
            title: Text(
              (selectedCliente?.nombreCompleto?.isNotEmpty == true)
                  ? selectedCliente!.nombreCompleto!
                  : (selectedCliente?.documentoNit?.isNotEmpty == true)
                  ? selectedCliente!.documentoNit!
                  : (widget.fallbackName?.isNotEmpty == true)
                  ? widget.fallbackName!
                  : (widget.selectedClienteId != null
                      ? 'Cliente #${widget.selectedClienteId}'
                      : 'Seleccionar cliente'),
            ),
            subtitle:
                selectedCliente != null
                    ? Text(selectedCliente.ciudadNombre ?? 'Sin ciudad')
                    : const Text('Toca para seleccionar un cliente'),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () => _showClienteSelector(context, provider),
          ),
        );
      },
    );
  }

  void _showClienteSelector(BuildContext context, PlantillaProvider provider) {
    // 🔄 Refrescar lista de clientes al abrir el selector
    provider.loadClientes();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => Consumer<PlantillaProvider>(
                  builder:
                      (context, provider, child) => Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Seleccionar Cliente',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar cliente...',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon:
                                        _searchQuery.isNotEmpty
                                            ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _searchController.clear();
                                                _searchClientes('');
                                              },
                                            )
                                            : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  onChanged: (value) {
                                    // Actualizar búsqueda en el provider
                                    provider.loadClientes(
                                      busqueda: value.isEmpty ? null : value,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Lista de clientes
                          Expanded(
                            child:
                                provider.isLoadingClientes
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                    : provider.clientes.isEmpty
                                    ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.search_off,
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
                                      controller: scrollController,
                                      itemCount: provider.clientes.length,
                                      itemBuilder: (context, index) {
                                        final cliente =
                                            provider.clientes[index];
                                        final isSelected =
                                            cliente.id ==
                                            widget.selectedClienteId;

                                        final nombre =
                                            (cliente
                                                        .nombreCompleto
                                                        ?.isNotEmpty ==
                                                    true)
                                                ? cliente.nombreCompleto!
                                                : (cliente
                                                        .documentoNit
                                                        ?.isNotEmpty ==
                                                    true)
                                                ? cliente.documentoNit!
                                                : 'Cliente #${cliente.id}';

                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                isSelected
                                                    ? Colors.green[100]
                                                    : Theme.of(context).primaryColor.withOpacity(0.2),
                                            child: Icon(
                                              Icons.business,
                                              color:
                                                  isSelected
                                                      ? Colors.green[700]
                                                      : Theme.of(context).primaryColor,
                                            ),
                                          ),
                                          title: Text(nombre),
                                          subtitle: Text(
                                            cliente.ciudadNombre ??
                                                'Sin ciudad',
                                          ),
                                          trailing:
                                              isSelected
                                                  ? const Icon(
                                                    Icons.check,
                                                    color: Colors.green,
                                                  )
                                                  : null,
                                          onTap: () {
                                            widget.onClienteSelected(
                                              cliente.id,
                                            );
                                            Navigator.pop(context);
                                          },
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                ),
          ),
    );
  }
}
