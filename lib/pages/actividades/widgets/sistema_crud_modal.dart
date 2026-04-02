import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/widgets/upper_case_formatter.dart';
import '../../inspecciones/models/sistema_model.dart';
import '../../inspecciones/providers/sistemas_provider.dart';

class SistemaCrudModal extends StatefulWidget {
  final SistemaModel? sistema;

  const SistemaCrudModal({super.key, this.sistema});

  @override
  State<SistemaCrudModal> createState() => _SistemaCrudModalState();
}

class _SistemaCrudModalState extends State<SistemaCrudModal> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  bool _activo = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.sistema != null) {
      _nombreController.text = widget.sistema!.nombre ?? '';
      _descripcionController.text = widget.sistema!.descripcion ?? '';
      _activo = widget.sistema!.activo ?? true;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.sistema != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isEditing
                        ? PhosphorIcons.pencilSimple()
                        : PhosphorIcons.plusCircle(),
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Sistema' : 'Nuevo Sistema',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Nombre
              TextFormField(
                controller: _nombreController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Nombre del sistema *',
                  hintText: 'Ej: MOTOR',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(PhosphorIcons.gear()),
                ),
                inputFormatters: [UpperCaseTextFormatter()],
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Requerido'
                            : null,
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                enabled: !_isLoading,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Breve descripción del sistema...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(PhosphorIcons.textAlignLeft()),
                ),
              ),
              const SizedBox(height: 16),

              // Estado
              SwitchListTile(
                title: const Text('Estado'),
                subtitle: Text(
                  _activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    color: _activo ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _activo,
                onChanged:
                    _isLoading ? null : (val) => setState(() => _activo = val),
                activeThumbColor: Colors.green,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(isEditing ? 'Actualizar' : 'Crear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = context.read<SistemasProvider>();

    try {
      bool success;
      if (widget.sistema != null) {
        success = await provider.actualizarSistema(
          sistemaId: widget.sistema!.id!,
          nombre: _nombreController.text.trim().toUpperCase(),
          descripcion: _descripcionController.text.trim(),
          activo: _activo,
        );
      } else {
        success = await provider.crearSistema(
          nombre: _nombreController.text.trim().toUpperCase(),
          descripcion: _descripcionController.text.trim(),
          activo: _activo,
        );
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.sistema != null
                    ? 'Sistema actualizado exitosamente'
                    : 'Sistema creado exitosamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${provider.error ?? "No se pudo realizar la operación"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
