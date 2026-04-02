import 'package:flutter/material.dart';
import 'package:infoapp/core/utils/icon_fallback.dart';
import '../controllers/home_controller.dart';
import '../models/navigation_item_model.dart';

class DrawerExpansionMenu extends StatelessWidget {
  final NavigationItem item;
  final HomeController controller;
  final Color primaryColor;
  final Function(String) onNavigationChanged;

  const DrawerExpansionMenu({
    super.key,
    required this.item,
    required this.controller,
    required this.primaryColor,
    required this.onNavigationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: primaryColor),
      ),
      child: ExpansionTile(
        leading: AssetOrIcon(
          assetPath: item.assetIconPath,
          iconData: item.icon,
          color: controller.isAjustesSelected() ? primaryColor : Colors.grey.shade600,
        ),
        title: Text(item.title),
        iconColor: primaryColor,
        collapsedIconColor: Colors.grey.shade600,
        children:
            item.children?.map((child) {
              final isSelected = controller.vistaActual == child.id;
              return ListTile(
                leading: const SizedBox(width: 24),
                title: Text(child.title),
                selected: isSelected,
                selectedTileColor: primaryColor.withOpacity(0.1),
                onTap: () {
                  onNavigationChanged(child.id);
                  Navigator.pop(context);
                },
              );
            }).toList() ??
            [],
      ),
    );
  }
}
