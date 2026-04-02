import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/workflow/estado_workflow_models.dart';

class UmwFirmasTab extends StatelessWidget {
  final ServicioModel servicio;
  final List<WorkflowTransicionDef> accionesDisponibles;
  final bool estaBloqueado;
  final VoidCallback onIniciarFirma;
  final VoidCallback? onConfirmarFirma;

  const UmwFirmasTab({
    super.key,
    required this.servicio,
    required this.accionesDisponibles,
    this.estaBloqueado = false,
    required this.onIniciarFirma,
    this.onConfirmarFirma,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tieneFirma = servicio.tieneFirma ?? false;
    // Se considera confirmado si el trigger ya se disparó o si el servicio ya está finalizado comercialmente
    final isConfirmado = servicio.isFirmaConfirmada;
    final requiereConfirmacion = accionesDisponibles.any((a) => a.triggerCode == 'FIRMA_CLIENTE');

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusCard(context, tieneFirma, isConfirmado),
          const SizedBox(height: 24),
          
          ElevatedButton.icon(
            onPressed: estaBloqueado ? null : onIniciarFirma,
            icon: Icon(tieneFirma ? PhosphorIcons.eye() : PhosphorIcons.signature()),
            label: Text(
              tieneFirma ? 'Ver Detalles de Firma' : 'Iniciar Proceso de Entrega y Firma',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: tieneFirma 
                ? Colors.blue.withOpacity(0.1) 
                : theme.primaryColor.withOpacity(0.1),
              foregroundColor: tieneFirma ? Colors.blue.shade700 : theme.primaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (!tieneFirma) ...[
            const SizedBox(height: 16),
            const Text(
              'Este proceso registrará la fecha de finalización y capturará las firmas del personal y del cliente.',
              style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],

          if (tieneFirma && requiereConfirmacion && !isConfirmado) ...[
             const SizedBox(height: 24),
             const Divider(),
             const SizedBox(height: 12),
             _buildConfirmButton(context),
          ],

          if (isConfirmado) ...[
             const SizedBox(height: 32),
             Center(
               child: Column(
                 children: [
                   Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), color: Colors.green, size: 64),
                   const SizedBox(height: 16),
                   const Text(
                     'Firma Completada',
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                     textAlign: TextAlign.center,
                   ),
                   const SizedBox(height: 8),
                   const Text(
                     'La entrega ha sido procesada correctamente.',
                     style: TextStyle(color: Colors.grey),
                   ),
                 ],
               ),
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, bool tieneFirma, bool isConfirmado) {
    Color cardColor = Colors.orange.shade50;
    Color borderColor = Colors.orange.shade200;
    Color textColor = Colors.orange.shade800;
    Color iconColor = Colors.orange;
    String title = 'Firma Pendiente';
    String message = 'Se requiere la firma del cliente para finalizar el servicio.';
    IconData icon = PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);

    if (isConfirmado) {
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      textColor = Colors.green.shade800;
      iconColor = Colors.green;
      title = 'Servicio Entregado';
      message = 'La entrega y firma han sido registradas y finalizadas.';
      icon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
    } else if (tieneFirma) {
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      textColor = Colors.blue.shade800;
      iconColor = Colors.blue;
      title = 'Firma Registrada';
      message = 'La firma ya existe. Presione "Confirmar Firma" para procesar el cambio de estado.';
      icon = PhosphorIcons.signature(PhosphorIconsStyle.fill);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: estaBloqueado ? null : onConfirmarFirma,
        icon: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)),
        label: const Text(
          'Confirmar Firma de Cliente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.withOpacity(0.1),
          foregroundColor: Colors.green,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
