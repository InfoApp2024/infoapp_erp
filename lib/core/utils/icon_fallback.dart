import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class AssetOrIcon extends StatelessWidget {
  final String? assetPath;
  final IconData iconData;
  final double? size;
  final Color? color;

  const AssetOrIcon({
    super.key,
    required this.iconData,
    this.assetPath,
    this.size,
    this.color,
  });

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (assetPath == null || assetPath!.isEmpty) {
      return Icon(iconData, size: size, color: color);
    }
    return FutureBuilder<bool>(
      future: _assetExists(assetPath!),
      builder: (context, snapshot) {
        final exists = snapshot.connectionState == ConnectionState.done && (snapshot.data ?? false);
        if (exists) {
          return ImageIcon(AssetImage(assetPath!), size: size, color: color);
        }
        return Icon(iconData, size: size, color: color);
      },
    );
  }
}