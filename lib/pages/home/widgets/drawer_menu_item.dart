import 'package:flutter/material.dart';
import 'package:infoapp/core/utils/icon_fallback.dart';
import '../controllers/home_controller.dart';
import '../models/navigation_item_model.dart';
// ThemeProvider import eliminado, se recibe el color directamente

class DrawerMenuItem extends StatelessWidget {
  final NavigationItem item;
  final HomeController controller;
  final Color primaryColor;
  final Function(String) onNavigationChanged;
  final bool isSidebar;

  const DrawerMenuItem({
    super.key,
    required this.item,
    required this.controller,
    required this.primaryColor,
    required this.onNavigationChanged,
    this.isSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.vistaActual == item.id;
    final isCollapsed = isSidebar && controller.isSidebarCollapsed;
    final color = isSidebar ? Colors.white : primaryColor;
    final inactiveColor = isSidebar ? Colors.white70 : Colors.grey.shade600;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axis: Axis.horizontal,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: isCollapsed
          ? Tooltip(
              key: const ValueKey('collapsed'),
              message: item.title,
              child: InkWell(
                onTap: () => onNavigationChanged(item.id),
                child: Container(
                  height: 50,
                  width: 80,
                  alignment: Alignment.center,
                  child: AssetOrIcon(
                    assetPath: item.assetIconPath,
                    iconData: item.icon,
                    color: isSelected ? color : inactiveColor,
                  ),
                ),
              ),
            )
          : ListTile(
              key: const ValueKey('expanded'),
              leading: AssetOrIcon(
                assetPath: item.assetIconPath,
                iconData: item.icon,
                color: isSelected ? color : inactiveColor,
              ),
              title: Text(
                item.title,
                style: TextStyle(
                    color: isSidebar
                        ? (isSelected ? Colors.white : Colors.white70)
                        : null),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: isSelected,
              selectedTileColor: isSidebar
                  ? Colors.white.withOpacity(0.1)
                  : primaryColor.withOpacity(0.1),
              onTap: () {
                onNavigationChanged(item.id);
                if (!isSidebar) Navigator.pop(context);
              },
            ),
    );
  }
}
