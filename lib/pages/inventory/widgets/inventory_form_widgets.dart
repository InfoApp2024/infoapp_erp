// lib/pages/inventory/widgets/inventory_form_widgets.dart

import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:flutter/services.dart';
import 'package:infoapp/widgets/currency_input_formatter.dart';
import 'package:infoapp/core/utils/currency_utils.dart';

// Importar los modelos
import '../models/inventory_category_model.dart';
import '../models/inventory_item_model.dart'; // ✅ NUEVO IMPORT

/// =====================================================
/// INFORMACIÓN SOBRE ESTE ARCHIVO DE WIDGETS
/// =====================================================
///
/// Este archivo contiene todos los widgets personalizados utilizados
/// en el formulario de inventario (InventoryFormPage).
///
/// WIDGETS INCLUIDOS:
/// - InventorySkuField: Campo especializado para SKU con validación
/// - InventoryTextField: Campo de texto genérico con configuraciones
/// - InventoryNumberField: Campo numérico con formateo
/// - InventoryPriceSection: Sección completa de precios con preview
/// - InventoryStockPreview: Preview visual del estado del stock
/// - InventoryLocationPreview: Preview de ubicación completa
/// - InventoryCategoryDropdown: Dropdown de categorías
/// - InventoryTypeDropdown: Dropdown de tipos de item
/// - InventoryUnitDropdown: Dropdown de unidades de medida
/// - InventorySupplierSection: Sección completa de gestión de proveedores
/// - InventoryItemStatusWidget: Widget para gestión de estado activo/inactivo ✅ NUEVO
/// - InventoryStatusChangeDialog: Diálogo de confirmación para cambio de estado ✅ NUEVO
/// - InactiveItemsSection: Sección para mostrar items inactivos ✅ NUEVO
/// - ItemStatusInfoWidget: Widget informativo de estadísticas de estado ✅ NUEVO
///
/// DONDE SE UTILIZA:
/// - Principalmente en InventoryFormPage para crear/editar items
/// - Puede ser reutilizado en otros formularios relacionados con inventario
///
/// BENEFICIOS DE LA SEPARACIÓN:
/// - Código más modular y mantenible
/// - Widgets reutilizables
/// - Separación de responsabilidades
/// - Facilita testing unitario de widgets
/// - Mejora la legibilidad del código principal
/// =====================================================

/// Formateador para forzar mayúsculas en campos de texto
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Widget especializado para el campo SKU con validación en tiempo real
class InventorySkuField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final String? errorText;
  final bool isChecking;
  final bool isAvailable;
  final List<String> suggestions;
  final Function(String) onChanged;
  final VoidCallback? onSuggestionsPressed;

  const InventorySkuField({
    super.key,
    required this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.errorText,
    this.isChecking = false,
    this.isAvailable = true,
    this.suggestions = const [],
    required this.onChanged,
    this.onSuggestionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'SKU *',
                  hintText: 'Código único del item',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                  suffixIcon:
                      isChecking
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : isAvailable
                          ? const Icon(Icons.check, color: Colors.green)
                          : const Icon(Icons.error, color: Colors.red),
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                onChanged: onChanged,
                onFieldSubmitted: (_) {
                  if (nextFocusNode != null) {
                    FocusScope.of(context).requestFocus(nextFocusNode);
                  }
                },
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.lightbulb_outline),
                onPressed: onSuggestionsPressed,
                tooltip: 'Ver sugerencias',
              ),
            ],
          ],
        ),
        if (!isAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Este SKU ya existe. ${suggestions.isNotEmpty ? 'Toca el ícono para ver sugerencias.' : ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget genérico para campos de texto con configuraciones estándar
class InventoryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final String? prefixText;
  final bool isRequired;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final Function(String)? onChanged;

  const InventoryTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.focusNode,
    this.nextFocusNode,
    this.errorText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.characters,
    this.maxLines = 1,
    this.prefixText,
    this.isRequired = false,
    this.suffixIcon,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        errorText: errorText,
        prefixText: prefixText,
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
      ),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      inputFormatters: [
        UpperCaseTextFormatter(),
        ...?inputFormatters,
      ],
      onChanged: onChanged,
      textInputAction:
          nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        }
      },
    );
  }
}

/// Widget especializado para campos numéricos
class InventoryNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final String? errorText;
  final bool isDecimal;
  final String? prefixText;
  final Function()? onChanged;
  final bool isRequired;
  final bool enabled;
  final String? hintText;
  final List<TextInputFormatter>? customFormatters;

  const InventoryNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.nextFocusNode,
    this.errorText,
    this.isDecimal = false,
    this.prefixText,
    this.onChanged,
    this.isRequired = false,
    this.enabled = true,
    this.hintText,
    this.customFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hintText,
        errorText: errorText,
        prefixText: prefixText,
        border: const OutlineInputBorder(),
        filled: !enabled,
        fillColor: !enabled ? Colors.grey.shade200 : null,
      ),
      keyboardType:
          isDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
      inputFormatters: customFormatters ?? [
        if (isDecimal)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      textInputAction:
          nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      onChanged: (_) => onChanged?.call(),
      onFieldSubmitted: (_) {
        if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        }
      },
    );
  }
}

/// Sección completa de precios con preview de márgenes
class InventoryPriceSection extends StatelessWidget {
  final TextEditingController unitCostController;
  final TextEditingController? initialCostController;
  final TextEditingController averageCostController;
  final TextEditingController lastCostController;
  final List<FocusNode> focusNodes;
  final Map<String, String> validationErrors;
  final bool isEditMode;

  const InventoryPriceSection({
    super.key,
    required this.unitCostController,
    this.initialCostController,
    required this.averageCostController,
    required this.lastCostController,
    required this.focusNodes,
    required this.validationErrors,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información de Precios',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (initialCostController != null && !isEditMode) ...[
              InventoryNumberField(
                controller: initialCostController!,
                label: 'Costo Inicial (Compra)',
                focusNode: focusNodes.length > 7 ? focusNodes[7] : null,
                nextFocusNode: focusNodes.length > 8 ? focusNodes[8] : null,
                errorText: validationErrors['initialCost'],
                isDecimal: true,
                prefixText: '\$ ',
                isRequired: true,
                hintText: '0.00',
                customFormatters: [CurrencyInputFormatter()],
                onChanged: () => (context as Element).markNeedsBuild(),
              ),
              const SizedBox(height: 16),
            ],
            InventoryNumberField(
              controller: unitCostController,
              label: 'Precio de Venta',
              focusNode: focusNodes.length > 8 ? focusNodes[8] : null,
              nextFocusNode: focusNodes.length > 9 ? focusNodes[9] : null,
              errorText: validationErrors['unitCost'],
              isDecimal: true,
              prefixText: '\$ ',
              isRequired: true,
              hintText: '0.00',
              customFormatters: [CurrencyInputFormatter()],
              onChanged: () => (context as Element).markNeedsBuild(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InventoryNumberField(
                    controller: averageCostController,
                    label: 'Costo Promedio',
                    focusNode: focusNodes.length > 9 ? focusNodes[9] : null,
                    nextFocusNode:
                        focusNodes.length > 10 ? focusNodes[10] : null,
                    errorText: validationErrors['averageCost'],
                    isDecimal: true,
                    prefixText: '\$ ',
                    hintText: '0.00',
                    customFormatters: [CurrencyInputFormatter()],
                    enabled: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InventoryNumberField(
                    controller: lastCostController,
                    label: 'Último Costo',
                    focusNode: focusNodes.length > 10 ? focusNodes[10] : null,
                    nextFocusNode:
                        focusNodes.length > 11 ? focusNodes[11] : null,
                    errorText: validationErrors['lastCost'],
                    isDecimal: true,
                    prefixText: '\$ ',
                    hintText: '0.00',
                    customFormatters: [CurrencyInputFormatter()],
                    enabled: false,
                  ),
                ),
              ],
            ),
            if (unitCostController.text.isNotEmpty &&
                (averageCostController.text.isNotEmpty ||
                    (initialCostController?.text.isNotEmpty ?? false)))
              InventoryMarginPreview(
                unitCost: CurrencyUtils.parse(unitCostController.text),
                averageCost:
                    averageCostController.text.isNotEmpty
                        ? CurrencyUtils.parse(averageCostController.text)
                        : CurrencyUtils.parse(initialCostController?.text ?? '0'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget para mostrar el preview de márgenes de ganancia
class InventoryMarginPreview extends StatelessWidget {
  final double unitCost;
  final double averageCost;

  const InventoryMarginPreview({
    super.key,
    required this.unitCost,
    required this.averageCost,
  });

  @override
  Widget build(BuildContext context) {
    if (unitCost <= 0 || averageCost <= 0) {
      return const SizedBox.shrink();
    }

    // Cálculo del Margen de Utilidad (Gross Margin)
    // Fórmula: (Precio Venta - Costo) / Precio Venta
    final profit = unitCost - averageCost;
    final margin = unitCost > 0 ? (profit / unitCost * 100) : 0.0;

    // Determinar colores y mensajes según el resultado
    Color bgColor;
    Color borderColor;
    Color textColor;
    String message;
    IconData icon;

    if (profit > 0) {
      // GANANCIA
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      textColor = Colors.green.shade800;
      message = 'GANANCIA';
      icon = Icons.trending_up;
    } else if (profit == 0) {
      // SIN GANANCIA
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      textColor = Colors.orange.shade800;
      message = 'SIN GANANCIA: PRECIO DE VENTA IGUAL AL COSTO';
      icon = Icons.trending_flat;
    } else {
      // PÉRDIDA
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade800;
      message = 'PÉRDIDA: EL PRECIO DE VENTA ES MENOR AL COSTO';
      icon = Icons.trending_down;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              if (profit != 0)
                Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VALOR ABSOLUTO:',
                style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7)),
              ),
              Text(
                '\$ ${CurrencyUtils.format(profit)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget para mostrar el preview del estado del stock
class InventoryStockPreview extends StatelessWidget {
  final double currentStock;
  final double minimumStock;
  final double? maximumStock;

  const InventoryStockPreview({
    super.key,
    required this.currentStock,
    required this.minimumStock,
    this.maximumStock,
  });

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (currentStock == 0 && minimumStock == 0) {
      return const SizedBox.shrink();
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (currentStock == 0) {
      statusColor = context.errorColor;
      statusText = 'Sin Stock';
      statusIcon = Icons.error;
    } else if (currentStock <= minimumStock) {
      statusColor = context.warningColor;
      statusText = 'Stock Bajo';
      statusIcon = Icons.warning;
    } else if (maximumStock != null && currentStock >= maximumStock!) {
      statusColor = Theme.of(context).colorScheme.primary;
      statusText = 'Stock Alto';
      statusIcon = Icons.info;
    } else {
      statusColor = context.successColor;
      statusText = 'STOCK NORMAL';
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTADO DEL STOCK',
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
                Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (maximumStock != null)
            Text(
              '${_formatNumber(currentStock)} / ${_formatNumber(maximumStock!)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: statusColor),
            ),
        ],
      ),
    );
  }
}

/// Widget para mostrar el preview de ubicación completa
class InventoryLocationPreview extends StatelessWidget {
  final String? location;
  final String? shelf;
  final String? bin;

  const InventoryLocationPreview({
    super.key,
    this.location,
    this.shelf,
    this.bin,
  });

  String _getFullLocationPreview() {
    List<String> locationParts = [];

    if (location?.trim().isNotEmpty == true) {
      locationParts.add(location!.trim());
    }
    if (shelf?.trim().isNotEmpty == true) {
      locationParts.add('Estante: ${shelf!.trim()}');
    }
    if (bin?.trim().isNotEmpty == true) {
      locationParts.add('Bin: ${bin!.trim()}');
    }

    return locationParts.isEmpty
        ? 'NO SE HA ESPECIFICADO UBICACIÓN'
        : locationParts.join(' - ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UBICACIÓN COMPLETA',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _getFullLocationPreview(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown especializado para categorías
class InventoryCategoryDropdown extends StatelessWidget {
  final int? selectedCategoryId;
  final List<InventoryCategory> categories;
  final Function(int?) onChanged;
  final VoidCallback? onAddPressed;

  const InventoryCategoryDropdown({
    super.key,
    required this.selectedCategoryId,
    required this.categories,
    required this.onChanged,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: selectedCategoryId,
      decoration: const InputDecoration(
        labelText: 'Categoría',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('SIN CATEGORÍA')),
        ...categories.map(
          (category) => DropdownMenuItem<int?>(
            value:
                category.id != null
                    ? int.tryParse(category.id.toString())
                    : null,
            child: Text(category.name.toUpperCase()),
          ),
        ),
        if (onAddPressed != null)
          DropdownMenuItem<int?>(
            value: -1, // Valor especial para "Agregar nuevo"
            child: Row(
              children: [
                Icon(Icons.add, size: 18, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Agregar nueva categoría...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (value) {
        if (value == -1) {
          onAddPressed?.call();
        } else {
          onChanged(value);
        }
      },
    );
  }
}

/// Dropdown dinámico que permite seleccionar de una lista o agregar nuevo valor
class InventoryDynamicDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final Function(String) onChanged;
  final String label;
  final String? errorText;
  final bool isRequired;

  const InventoryDynamicDropdown({
    super.key,
    this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    this.errorText,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    // Asegurar que el valor actual esté en la lista si no es nulo
    final effectiveItems = List<String>.from(items);
    if (value != null &&
        value!.isNotEmpty &&
        !effectiveItems.contains(value)) {
      effectiveItems.add(value!);
    }

    // Ordenar alfabéticamente
    effectiveItems.sort();

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
      items: [
        ...effectiveItems.map(
          (item) => DropdownMenuItem(value: item, child: Text(item.toUpperCase())),
        ),
        DropdownMenuItem(
          value: '__add_new__',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 18, color: Theme.of(context).primaryColor),
              SizedBox(width: 8),
              Text(
                'AGREGAR NUEVO...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: (newValue) {
        if (newValue == '__add_new__') {
          _showAddDialog(context);
        } else if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('AGREGAR ${label.toUpperCase()}'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'NUEVO ${label.toUpperCase()}',
                border: const OutlineInputBorder(),
                hintText: 'INGRESE EL NOMBRE',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    onChanged(text);
                    Navigator.pop(context);
                  }
                },
                child: const Text('AGREGAR'),
              ),
            ],
          ),
    );
  }
}

/// Dropdown especializado para unidades de medida
class InventoryUnitDropdown extends StatelessWidget {
  final String selectedUnit;
  final Function(String) onChanged;
  final bool isRequired;
  final String? errorText;

  const InventoryUnitDropdown({
    super.key,
    required this.selectedUnit,
    required this.onChanged,
    this.isRequired = false,
    this.errorText,
  });

  // Lista oficial de unidades proporcionada por el usuario
  static final List<Map<String, String>> _unitsData = [
    {'code': 'UND', 'desc': 'UNIDAD', 'tipo': 'CANTIDAD'},
    {'code': 'PZA', 'desc': 'PIEZA', 'tipo': 'CANTIDAD'},
    {'code': 'KIT', 'desc': 'KIT', 'tipo': 'CANTIDAD'},
    {'code': 'JGO', 'desc': 'JUEGO', 'tipo': 'CANTIDAD'},
    {'code': 'PAR', 'desc': 'PAR', 'tipo': 'CANTIDAD'},
    {'code': 'M', 'desc': 'METRO', 'tipo': 'LONGITUD'},
    {'code': 'CM', 'desc': 'CENTÍMETRO', 'tipo': 'LONGITUD'},
    {'code': 'MM', 'desc': 'MILÍMETRO', 'tipo': 'LONGITUD'},
    {'code': 'KM', 'desc': 'KILÓMETRO', 'tipo': 'LONGITUD'},
    {'code': 'KG', 'desc': 'KILOGRAMO', 'tipo': 'PESO'},
    {'code': 'G', 'desc': 'GRAMO', 'tipo': 'PESO'},
    {'code': 'LB', 'desc': 'LIBRA', 'tipo': 'PESO'},
    {'code': 'L', 'desc': 'LITRO', 'tipo': 'VOLUMEN'},
    {'code': 'ML', 'desc': 'MILILITRO', 'tipo': 'VOLUMEN'},
    {'code': 'GAL', 'desc': 'GALÓN', 'tipo': 'VOLUMEN'},
    {'code': 'CAJ', 'desc': 'CAJA', 'tipo': 'EMPAQUE'},
    {'code': 'PAQ', 'desc': 'PAQUETE', 'tipo': 'EMPAQUE'},
    {'code': 'BL', 'desc': 'BLISTER', 'tipo': 'EMPAQUE'},
    {'code': 'ROL', 'desc': 'ROLLO', 'tipo': 'EMPAQUE'},
    {'code': 'SAC', 'desc': 'SACO', 'tipo': 'EMPAQUE'},
    {'code': 'HR', 'desc': 'HORA', 'tipo': 'TIEMPO'},
    {'code': 'DIA', 'desc': 'DÍA', 'tipo': 'TIEMPO'},
    {'code': 'SERV', 'desc': 'SERVICIO', 'tipo': 'SERVICIOS'},
  ];

  @override
  Widget build(BuildContext context) {
    // Buscar descripción de la unidad seleccionada
    final selectedUnitData = _unitsData.firstWhere(
      (u) => u['code'] == selectedUnit.toUpperCase(),
      orElse: () => {'code': selectedUnit, 'desc': selectedUnit, 'tipo': ''},
    );

    final String displayText =
        selectedUnit.isEmpty
            ? ''
            : '${selectedUnitData['code']} - ${selectedUnitData['desc']}';

    return GestureDetector(
      onTap: () => _showUnitPicker(context),
      child: AbsorbPointer(
        child: TextFormField(
          key: ValueKey('unit_field_$selectedUnit'),
          initialValue: displayText.toUpperCase(),
          decoration: InputDecoration(
            labelText: isRequired ? 'UNIDAD DE MEDIDA *' : 'UNIDAD DE MEDIDA',
            hintText: 'SELECCIONAR UNIDAD...',
            errorText: errorText?.toUpperCase(),
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            filled: true,
            fillColor: Colors.white,
          ),
          readOnly: true,
        ),
      ),
    );
  }

  void _showUnitPicker(BuildContext context) {
    // Agrupar unidades por tipo
    final Map<String, List<Map<String, String>>> groupedUnits = {};
    for (var unit in _unitsData) {
      final tipo = unit['tipo']!;
      if (!groupedUnits.containsKey(tipo)) {
        groupedUnits[tipo] = [];
      }
      groupedUnits[tipo]!.add(unit);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.straighten_outlined, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'SELECCIONAR UNIDAD DE MEDIDA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search (opcional para el futuro, por ahora solo lista)
              // List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children:
                      groupedUnits.keys.map((tipo) {
                        return _buildUnitSection(context, tipo, groupedUnits[tipo]!);
                      }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnitSection(
    BuildContext context,
    String tipo,
    List<Map<String, String>> units,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Text(
            tipo.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...units.map((unit) {
          final isSelected = selectedUnit.toUpperCase() == unit['code'];
          return ListTile(
            dense: true,
            leading: Icon(
              _getIconForTipo(tipo),
              size: 20,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
            title: Text(
              '${unit['code']} - ${unit['desc']}'.toUpperCase(),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.black87,
              ),
            ),
            trailing:
                isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
            onTap: () {
              onChanged(unit['code']!);
              Navigator.pop(context);
            },
          );
        }),
        const Divider(height: 1),
      ],
    );
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'CANTIDAD':
        return Icons.inventory_2_outlined;
      case 'LONGITUD':
        return Icons.straighten;
      case 'PESO':
        return Icons.scale;
      case 'VOLUMEN':
        return Icons.opacity;
      case 'EMPAQUE':
        return Icons.inventory;
      case 'TIEMPO':
        return Icons.timer;
      case 'SERVICIOS':
        return Icons.build;
      default:
        return Icons.category_outlined;
    }
  }
}

/// ✅ NUEVO: Widget para mostrar el estado del item con opción de cambio
class InventoryItemStatusWidget extends StatelessWidget {
  final bool isActive;
  final Function(bool) onStatusChanged;
  final bool isLoading;
  final bool showToggle;

  const InventoryItemStatusWidget({
    super.key,
    required this.isActive,
    required this.onStatusChanged,
    this.isLoading = false,
    this.showToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.cancel,
                  color: isActive ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado del Item',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Text(
                isActive ? 'ACTIVO' : 'INACTIVO',
                style: TextStyle(
                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            if (showToggle) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isActive
                          ? 'El item está disponible para uso'
                          : 'El item está inactivo y no aparece en búsquedas',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isActive,
                    onChanged: isLoading ? null : onStatusChanged,
                    activeThumbColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ✅ NUEVO: Diálogo de confirmación para cambio de estado
class InventoryStatusChangeDialog extends StatefulWidget {
  final bool currentStatus;
  final String itemName;
  final String itemSku;
  final Function(bool, String?) onConfirm;

  const InventoryStatusChangeDialog({
    super.key,
    required this.currentStatus,
    required this.itemName,
    required this.itemSku,
    required this.onConfirm,
  });

  @override
  State<InventoryStatusChangeDialog> createState() =>
      _InventoryStatusChangeDialogState();
}

class _InventoryStatusChangeDialogState
    extends State<InventoryStatusChangeDialog> {
  final _reasonController = TextEditingController();
  bool _requireReason = false;

  @override
  void initState() {
    super.initState();
    // Requerir razón solo cuando se inactiva
    _requireReason = widget.currentStatus; // Si está activo y se va a inactivar
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newStatus = !widget.currentStatus;
    final actionText = newStatus ? 'activar' : 'inactivar';
    final statusText = newStatus ? 'ACTIVO' : 'INACTIVO';
    final statusColor = newStatus ? Colors.green : Colors.red;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            newStatus ? Icons.check_circle : Icons.cancel,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text('Confirmar ${actionText.toUpperCase()}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Estás seguro de que deseas $actionText este item?'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item: ${widget.itemName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('SKU: ${widget.itemSku}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Estado actual: '),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            widget.currentStatus
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              widget.currentStatus
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        widget.currentStatus ? 'ACTIVO' : 'INACTIVO',
                        style: TextStyle(
                          color:
                              widget.currentStatus
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Nuevo estado: '),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_requireReason) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Razón (opcional)',
                hintText: 'Motivo para inactivar el item',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: newStatus ? Colors.blue.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color:
                      newStatus ? Colors.blue.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    newStatus
                        ? 'El item volverá a aparecer en búsquedas y estará disponible para uso.'
                        : 'El item dejará de aparecer en búsquedas normales, pero mantendrá su historial.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          newStatus
                              ? Colors.blue.shade700
                              : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _reasonController.text.trim();
            widget.onConfirm(newStatus, reason.isEmpty ? null : reason);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
          ),
          child: Text(actionText.toUpperCase()),
        ),
      ],
    );
  }
}

/// ✅ NUEVO: Widget para mostrar lista de items inactivos
class InactiveItemsSection extends StatelessWidget {
  final List<InventoryItem> inactiveItems;
  final bool isLoading;
  final Function(InventoryItem) onItemTap;
  final Function(InventoryItem) onReactivate;
  final VoidCallback? onViewAll;

  const InactiveItemsSection({
    super.key,
    required this.inactiveItems,
    this.isLoading = false,
    required this.onItemTap,
    required this.onReactivate,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Cargando items inactivos...'),
            ],
          ),
        ),
      );
    }

    if (inactiveItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 8),
              Text(
                'No hay items inactivos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Todos los items están activos',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Items Inactivos (${inactiveItems.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('Ver todos'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...inactiveItems
                .take(3)
                .map((item) => _buildInactiveItemTile(context, item)),
            if (inactiveItems.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: onViewAll,
                  icon: const Icon(Icons.expand_more),
                  label: Text('Ver ${inactiveItems.length - 3} más'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveItemTile(BuildContext context, InventoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'SKU: ${item.sku}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (item.categoryName != null)
                  Text(
                    item.categoryName!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => onItemTap(item),
                icon: const Icon(Icons.visibility),
                iconSize: 20,
                tooltip: 'Ver detalles',
              ),
              IconButton(
                onPressed: () => onReactivate(item),
                icon: const Icon(Icons.refresh),
                iconSize: 20,
                color: Colors.green,
                tooltip: 'Reactivar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ✅ NUEVO: Widget de información sobre estado de items
class ItemStatusInfoWidget extends StatelessWidget {
  final int activeCount;
  final int inactiveCount;
  final VoidCallback? onManageInactive;

  const ItemStatusInfoWidget({
    super.key,
    required this.activeCount,
    required this.inactiveCount,
    this.onManageInactive,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = activeCount + inactiveCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado de Items',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    'Activos',
                    activeCount,
                    Colors.green,
                    Icons.check_circle,
                    totalCount > 0 ? (activeCount / totalCount * 100) : 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusCard(
                    'Inactivos',
                    inactiveCount,
                    Colors.red,
                    Icons.cancel,
                    totalCount > 0 ? (inactiveCount / totalCount * 100) : 0,
                  ),
                ),
              ],
            ),
            if (inactiveCount > 0 && onManageInactive != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onManageInactive,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Gestionar Items Inactivos'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    String label,
    int count,
    Color color,
    IconData icon,
    double percentage,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
