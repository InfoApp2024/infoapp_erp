import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../inspecciones/models/sistema_model.dart';
import '../../inspecciones/providers/sistemas_provider.dart';
import 'package:provider/provider.dart';

class SistemaSelectorCampo extends StatelessWidget {
  final int? sistemaId;
  final Function(SistemaModel?) onChanged;
  final String? Function(int?)? validator;
  final bool enabled;

  const SistemaSelectorCampo({
    super.key,
    required this.sistemaId,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SistemasProvider>(context);
    final sistemas = provider.sistemas;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownSearch<SistemaModel>(
        items: (filter, loadProps) => sistemas,
        selectedItem: sistemaId != null 
            ? sistemas.firstWhere((s) => s.id == sistemaId, orElse: () => sistemas.first)
            : null,
        enabled: enabled,
        compareFn: (item, selectedItem) => item.id == selectedItem.id,
        itemAsString: (item) => item.nombre ?? '',
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Buscar sistema...',
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          constraints: const BoxConstraints(maxHeight: 350),
          itemBuilder: (context, item, isDisabled, isSelected) => ListTile(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                (item.nombre ?? '?').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor
                ),
              ),
            ),
            title: Text(
              item.nombre ?? 'N/A',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: item.descripcion != null && item.descripcion!.isNotEmpty
                ? Text(
                    item.descripcion!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  )
                : null,
          ),
        ),
        decoratorProps: DropDownDecoratorProps(
          decoration: InputDecoration(
            labelText: 'Seleccionar Sistema',
            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
            prefixIcon: Icon(
              PhosphorIcons.gear(),
              color: Theme.of(context).primaryColor,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        dropdownBuilder: (context, selectedItem) {
          if (selectedItem == null) {
            return Text(
            'Seleccione un sistema',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          );
          }
          return Row(
            children: [
              Text(
                selectedItem.nombre ?? '',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          );
        },
        validator: (item) {
          if (validator != null) return validator!(item?.id);
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }
}
