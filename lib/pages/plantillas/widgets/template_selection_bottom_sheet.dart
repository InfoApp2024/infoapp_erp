import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/plantilla_model.dart';
import '../providers/plantilla_provider.dart';

class TemplateSelectionBottomSheet extends StatefulWidget {
  final int? clienteId;
  final Function(Plantilla) onSelected;

  const TemplateSelectionBottomSheet({
    super.key,
    this.clienteId,
    required this.onSelected,
  });

  @override
  State<TemplateSelectionBottomSheet> createState() => _TemplateSelectionBottomSheetState();
}

class _TemplateSelectionBottomSheetState extends State<TemplateSelectionBottomSheet> {
  bool _isLoading = true;
  List<Plantilla> _templates = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final provider = context.read<PlantillaProvider>();
      
      // Cargar plantillas del cliente y generales
      final templates = await provider.fetchTemplatesForSelection(clienteId: widget.clienteId);
      
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Seleccionar Plantilla de Informe',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige el tipo de reporte que deseas generar',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            )
          else if (_templates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No hay plantillas disponibles para este cliente'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _templates.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final template = _templates[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(PhosphorIcons.filePdf(), color: Colors.red[700]),
                    ),
                    title: Text(
                      template.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      template.esGeneral ? 'Plantilla General' : 'Específica del Cliente',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Icon(PhosphorIcons.caretRight(), size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelected(template);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
