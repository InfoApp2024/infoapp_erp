import 'package:flutter/material.dart';

class NavigationItem {
  final String id;
  final String title;
  final IconData icon;
  final String? assetIconPath;
  final bool isExpansion;
  final List<NavigationItem>? children;
  final bool adminOnly;

  const NavigationItem({
    required this.id,
    required this.title,
    required this.icon,
    this.assetIconPath,
    this.isExpansion = false,
    this.children,
    this.adminOnly = false,
  });
}
