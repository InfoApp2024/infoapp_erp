import 'package:flutter/material.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/forms/widgets/fotos_servicio_widget.dart';

class FotosServicioPage extends StatelessWidget {
  final int servicioId;
  final ServicioModel servicio;
  final bool readOnly;

  const FotosServicioPage({
    super.key,
    required this.servicioId,
    required this.servicio,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos del Servicio'),
      ),
      body: FotosServicioWidget(
        servicioId: servicioId,
        numeroServicio: servicio.oServicio?.toString() ?? 'S/N',
        enabled: !readOnly,
      ),
    );
  }
}
