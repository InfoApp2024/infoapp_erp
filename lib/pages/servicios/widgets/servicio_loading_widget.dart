import 'package:flutter/material.dart';

class ServicioLoadingWidget extends StatelessWidget {
  final String? mensaje;

  const ServicioLoadingWidget({super.key, this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (mensaje != null) ...[
            const SizedBox(height: 16),
            Text(
              mensaje!,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
