import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_logo.dart';

class DrawerHeaderWidget extends StatelessWidget {
  final Color primaryColor;
  final String nombreUsuario;

  const DrawerHeaderWidget({
    super.key,
    required this.primaryColor,
    required this.nombreUsuario,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandingLogo(
              width: 60,
              height: 60,
              fallbackColor: Colors.white,
            ),
            const SizedBox(height: 12),
            const Text(
              'Menú Principal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              nombreUsuario,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
