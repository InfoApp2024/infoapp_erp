import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';

class MainContentArea extends StatelessWidget {
  final HomeController controller;

  const MainContentArea({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return controller.obtenerVista();
      },
    );
  }
}
