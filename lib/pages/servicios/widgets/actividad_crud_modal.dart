import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../models/actividad_estandar_model.dart';
import '../services/actividades_service.dart';
import 'package:infoapp/pages/actividades/widgets/sistema_selector_campo.dart';
import '../../inspecciones/providers/sistemas_provider.dart';

class ActividadCrudModal extends StatefulWidget {
  final ActividadEstandarModel? actividad;
  final Function(ActividadEstandarModel)? onGuardar;

  const ActividadCrudModal({super.key, this.actividad, this.onGuardar});

  @override
  State<ActividadCrudModal> createState() => _ActividadCrudModalState();
}

class _ActividadCrudModalState extends State<ActividadCrudModal> {
  final _formKey = GlobalKey<FormState>();
  final _actividadController = TextEditingController();
  final _cantHoraController = TextEditingController();
  final _numTecnicosController = TextEditingController();
  bool _activo = true;
  bool _isLoading = false;
  int? _sistemaIdSeleccionado;
  final _cantHoraFocus = FocusNode();
  final _numTecnicosFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.actividad != null) {
      _actividadController.text = widget.actividad!.actividad;
      // ✅ NO CARGAR CEROS
      _cantHoraController.text = widget.actividad!.cantHora > 0 
          ? widget.actividad!.cantHora.toStringAsFixed(2) 
          : '';
      _numTecnicosController.text = widget.actividad!.numTecnicos > 0 
          ? widget.actividad!.numTecnicos.toString() 
          : '';
      _activo = widget.actividad!.activo;
      _sistemaIdSeleccionado = widget.actividad!.sistemaId;
    }

    // ✅ LISTENERS PARA LIMPIAR CEROS AL ENTRAR (por si el usuario los escribe)
    _cantHoraFocus.addListener(() {
      if (_cantHoraFocus.hasFocus && (_cantHoraController.text == '0' || _cantHoraController.text == '0.0' || _cantHoraController.text == '0.00')) {
        _cantHoraController.clear();
      }
    });
    _numTecnicosFocus.addListener(() {
      if (_numTecnicosFocus.hasFocus && _numTecnicosController.text == '0') {
        _numTecnicosController.clear();
      }
    });

    // Cargar sistemas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SistemasProvider>().cargarSistemas(soloActivos: true);
    });
  }

  @override
  void dispose() {
    _actividadController.dispose();
    _cantHoraController.dispose();
    _numTecnicosController.dispose();
    _cantHoraFocus.dispose();
    _numTecnicosFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.actividad != null;

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
                    isEditing ? 'Editar Actividad' : 'Nueva Actividad',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Campo de actividad
              TextFormField(
                controller: _actividadController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Nombre de la actividad',
                  hintText: 'Ej: Cambio de aceite y filtro',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(PhosphorIcons.clipboardText()),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.trim().length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
                  if (value.length > 50) {
                    return 'Máximo 50 caracteres';
                  }
                  return null;
                },
                maxLength: 50,
                textCapitalization: TextCapitalization.characters,
              ),

              const SizedBox(height: 16),

              // Campo de Selección de Sistema (Premium)
              SistemaSelectorCampo(
                sistemaId: _sistemaIdSeleccionado,
                enabled: !_isLoading,
                onChanged: (sistema) {
                  setState(() {
                    _sistemaIdSeleccionado = sistema?.id;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'El sistema es obligatorio';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Nuevos campos: Horas y Técnicos
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cantHoraController,
                      focusNode: _cantHoraFocus, // ✅ AGREGADO
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Horas estimadas',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(PhosphorIcons.clock()),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) return null; // No obligatorio en UI, tendrá valor por defecto al guardar
                        final n = double.tryParse(value);
                        if (n == null || n < 0) return 'Número inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _numTecnicosController,
                      focusNode: _numTecnicosFocus, // ✅ AGREGADO
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Num. Técnicos *',
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(PhosphorIcons.users()),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) return null; // No obligatorio en UI, tendrá valor por defecto al guardar
                        final n = int.tryParse(value);
                        if (n == null || n < 1) return 'Mínimo 1';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              // Switch de estado activo
              SwitchListTile(
                title: const Text('Estado'),
                subtitle: Text(
                  _activo ? 'Activa' : 'Inactiva',
                  style: TextStyle(
                    color: _activo ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _activo,
                onChanged:
                    _isLoading
                        ? null
                        : (bool value) {
                          setState(() {
                            _activo = value;
                          });
                        },
                activeThumbColor: Colors.green,
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
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

    try {
      final actividadesService = context.read<ActividadesService>();
      ActividadEstandarModel actividadGuardada;

      if (widget.actividad != null) {
        // Actualizar
        final actividadActualizada = widget.actividad!.copyWith(
          actividad: _actividadController.text.trim().toUpperCase(),
          activo: _activo,
          cantHora: double.tryParse(_cantHoraController.text) ?? 0.00,
          numTecnicos: int.tryParse(_numTecnicosController.text) ?? 1,
          sistemaId: _sistemaIdSeleccionado,
        );

        await actividadesService.actualizarActividad(actividadActualizada);
        actividadGuardada = actividadActualizada;
      } else {
        // Crear nueva
        final textoActividad = _actividadController.text.trim().toUpperCase();
        final cantHora = double.tryParse(_cantHoraController.text) ?? 0.00;
        final numTecnicos = int.tryParse(_numTecnicosController.text) ?? 1;

        if (textoActividad.isEmpty) {
          throw Exception('Por favor ingrese el nombre de la actividad');
        }

        final nuevaActividad = await actividadesService.crearActividad(
          textoActividad,
          cantHora: cantHora,
          numTecnicos: numTecnicos,
          sistemaId: _sistemaIdSeleccionado,
        );

        if (nuevaActividad == null) {
          throw Exception('Error al crear la actividad');
        }

        actividadGuardada = nuevaActividad;
      }

      if (mounted) {
        Navigator.pop(context);

        // Llamar callback si existe
        widget.onGuardar?.call(actividadGuardada);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.actividad != null
                  ? 'Actividad actualizada exitosamente'
                  : 'Actividad creada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
