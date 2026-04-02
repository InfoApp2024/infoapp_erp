import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../models/cliente_model.dart';
import '../../services/servicios_api_service.dart';

/// Widget especializado para la selección de Clientes
class CampoCliente extends StatefulWidget {
  final int? clienteSeleccionado;
  final Function(ClienteModel?) onChanged;
  final String? Function(int?)? validator;
  final bool enabled;

  const CampoCliente({
    super.key,
    required this.clienteSeleccionado,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<CampoCliente> createState() => _CampoClienteState();
}

class _CampoClienteState extends State<CampoCliente> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<ClienteModel> _clientes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoading = true);
    try {
      final clientes = await ServiciosApiService.listarClientes();
      setState(() {
        _clientes = clientes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando clientes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  ClienteModel? _getClienteSeleccionado() {
    if (widget.clienteSeleccionado != null && _clientes.isNotEmpty) {
      try {
        return _clientes.firstWhere((c) => c.id == widget.clienteSeleccionado);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _clientes.isEmpty) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Row(
          children: [
             SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Cargando clientes...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.enabled ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(12),
        color: widget.enabled ? Colors.transparent : Colors.grey.shade50,
      ),
      child: DropdownSearch<ClienteModel>(
        items: (filter, loadProps) => _clientes,
        selectedItem: _getClienteSeleccionado(),
        enabled: widget.enabled,
        compareFn: (item, selectedItem) => item.id == selectedItem.id,
        itemAsString: (item) => item.descripcion,
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o NIT',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          constraints: const BoxConstraints(maxHeight: 300),
          itemBuilder: (context, item, isDisabled, isSelected) => ListTile(
            dense: true,
            title: Text(item.nombreCompleto),
            subtitle: Text(item.documentoNit, style: const TextStyle(fontSize: 11)),
            trailing: item.ciudad != null ? Text(item.ciudad!, style: const TextStyle(fontSize: 10)) : null,
          ),
        ),
        filterFn: (item, filter) {
          if (filter.isEmpty) return true;
          final f = filter.toLowerCase();
          return item.nombreCompleto.toLowerCase().contains(f) ||
                 item.documentoNit.toLowerCase().contains(f);
        },
        decoratorProps: DropDownDecoratorProps(
          decoration: InputDecoration(
            labelText: 'Seleccionar Cliente *',
            prefixIcon: Icon(
              Icons.business,
              color: widget.enabled ? Theme.of(context).primaryColor : Colors.grey,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        dropdownBuilder: (context, selectedItem) {
          if (selectedItem == null) return const SizedBox.shrink();
          return Text(
            selectedItem.nombreCompleto,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          );
        },
        validator: (cliente) {
          if (widget.validator != null) {
            return widget.validator!(cliente?.id);
          }
          return null;
        },
        onChanged: widget.onChanged,
      ),
    );
  }
}
