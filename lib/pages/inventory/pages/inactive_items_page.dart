// lib/pages/inventory/pages/inactive_items_page.dart

import 'package:flutter/material.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import '../models/inventory_item_model.dart';
import '../models/inventory_category_model.dart'; // ✅ AGREGAR IMPORT
import '../models/inventory_supplier_model.dart'; // ✅ AGREGAR IMPORT
import '../services/inventory_api_service.dart';
import 'inventory_form_page.dart';

class InactiveItemsPage extends StatefulWidget {
  const InactiveItemsPage({super.key});

  @override
  State<InactiveItemsPage> createState() => _InactiveItemsPageState();
}

class _InactiveItemsPageState extends State<InactiveItemsPage> {
  List<InventoryItem> _inactiveItems = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInactiveItems();
  }

  Future<void> _loadInactiveItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Si no hay conexión y este módulo no soporta offline, mostrar mensaje controlado
      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        NetErrorMessages.showOfflineModule(context, nombreModulo: 'Inventario');
        setState(() {
          _inactiveItems = [];
          _isLoading = false;
        });
        return;
      }

      // ✅ USAR getItems con parámetros específicos para items inactivos
      final response = await InventoryApiService.getItems(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        includeInactive: true, // Incluir items inactivos
        limit: 1000, // Límite alto para obtener todos
      );

      if (response.success && response.data != null) {
        // ✅ FILTRAR EXPLÍCITAMENTE SOLO LOS INACTIVOS
        final inactiveItems =
            response.data!.items
                .where(
                  (item) => item.isActive == false,
                ) // ✅ Comparación explícita con false
                .toList();


        setState(() {
          _inactiveItems = inactiveItems;
        });
      } else {
//         print('❌ Error en respuesta: ${response.message}');
        setState(() {
          _inactiveItems = [];
        });
      }
    } catch (e) {
//       print('❌ Excepción: $e');
      NetErrorMessages.showNetError(
        context,
        e,
        contexto: 'cargar items inactivos',
      );
      setState(() {
        _inactiveItems = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reactivateItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.refresh, color: Colors.green),
                SizedBox(width: 8),
                Text('Reactivar Item'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¿Estás seguro de que deseas reactivar este item?'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('SKU: ${item.sku}'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Reactivar'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final response = await InventoryApiService.toggleItemStatus(
          itemId: item.id!,
          isActive: true,
          reason: 'Reactivado desde gestión de items inactivos',
        );

        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item reactivado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _loadInactiveItems(); // Recargar lista
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ MÉTODO CORREGIDO: Navegar al formulario con datos cargados
  Future<void> _navigateToEditItem(InventoryItem item) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Cargar categorías y proveedores en paralelo
      final categoriesResponse = await InventoryApiService.getCategories(
        flat: true,
      );
      final suppliersResponse = await InventoryApiService.getSuppliers(
        limit: 100,
      );

      // ✅ EXTRAER DATOS CON CAST EXPLÍCITO
      final categories =
          categoriesResponse.success && categoriesResponse.data != null
              ? categoriesResponse.data!.categories
              : <InventoryCategory>[];

      final suppliers =
          suppliersResponse.success && suppliersResponse.data != null
              ? suppliersResponse.data!.suppliers
              : <InventorySupplier>[];

      // Cerrar indicador de carga
      if (mounted) Navigator.pop(context);

      // Navegar al formulario con datos reales
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => InventoryFormPage(
                  item: item,
                  categories: categories, // ✅ DATOS REALES
                  suppliers: suppliers, // ✅ DATOS REALES
                ),
          ),
        ).then((_) => _loadInactiveItems());
      }
    } catch (e) {
      // Cerrar indicador de carga en caso de error
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Items Inactivos'),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadInactiveItems,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar items inactivos',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              onSubmitted: (_) => _loadInactiveItems(),
            ),
          ),

          // Lista de items inactivos
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _inactiveItems.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No hay items inactivos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('Todos los items están activos'),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _inactiveItems.length,
                      itemBuilder: (context, index) {
                        final item = _inactiveItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.cancel,
                              color: Colors.red,
                            ),
                            title: Text(item.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SKU: ${item.sku}'),
                                if (item.categoryName != null)
                                  Text('Categoría: ${item.categoryName}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed:
                                      () => _navigateToEditItem(
                                        item,
                                      ), // ✅ USAR NUEVO MÉTODO
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  onPressed: () => _reactivateItem(item),
                                  icon: const Icon(Icons.refresh),
                                  color: Colors.green,
                                  tooltip: 'Reactivar',
                                ),
                              ],
                            ),
                            isThreeLine: item.categoryName != null,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
