import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/actividad_estandar_model.dart';
import '../providers/actividades_provider.dart';

class SelectorActividades extends StatefulWidget {
  final List<int> actividadesSeleccionadas;
  final List<int> actividadesDeInspeccion;
  final List<int> actividadesBloqueadas;
  final List<int> sistemasSeleccionados; // ✅ NUEVO: Sistemas elegidos en el form
  final bool showError;
  final Function(List<int>, Map<int, String>) onChanged;

  const SelectorActividades({
    super.key,
    required this.actividadesSeleccionadas,
    this.actividadesDeInspeccion = const [],
    this.actividadesBloqueadas = const [],
    this.sistemasSeleccionados = const [],
    this.showError = false,
    required this.onChanged,
  });

  @override
  State<SelectorActividades> createState() => _SelectorActividadesState();
}

class _SelectorActividadesState extends State<SelectorActividades> {
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();
  final bool _showOptions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showOverlay();
      } else {
        // Pequeño delay para permitir clic en opción
         Future.delayed(const Duration(milliseconds: 200), () {
           if (mounted && !_focusNode.hasFocus) {
             _hideOverlay();
           }
         });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: MediaQuery.of(context).size.width * 0.9, // O ajustar al ancho del padre
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 60),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Consumer<ActividadesProvider>(
                  builder: (context, provider, _) {
                    return _buildSuggestionsList(provider);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsList(ActividadesProvider provider) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final query = _searchController.text.toLowerCase();
    
    // 1. Filtrar locales (activos y no seleccionados)
    final filtered = provider.actividadesActivas.where((a) {
      final matchesQuery = a.actividad.toLowerCase().contains(query);
      final notSelected = !widget.actividadesSeleccionadas.contains(a.id);
      return matchesQuery && notSelected;
    }).toList();

    // 2. Filtrar estrictamente: Solo mostrar las que pertenecen a los sistemas seleccionados
    final available = filtered.where((a) {
      return widget.sistemasSeleccionados.contains(a.sistemaId);
    }).toList();

    if (available.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No hay actividades coincidentes o disponibles.'),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: available.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final actividad = available[index];

        return ListTile(
          title: Text(actividad.actividad),
          subtitle: const Text('Asociada al Sistema', 
            style: TextStyle(color: Colors.green, fontSize: 11)),
          trailing: Icon(PhosphorIcons.plusCircle(), color: Colors.green),
          onTap: () {
            _addActividad(actividad.id);
            _searchController.clear(); 
            _overlayEntry?.markNeedsBuild();
          },
        );
      },
    );
  }

  void _addActividad(int id) {
    if (widget.actividadesSeleccionadas.contains(id)) return;
    
    // Si se vuelve a agregar una que se había eliminado, quitar la nota
    _notasEliminacion.remove(id);
    final newList = List<int>.from(widget.actividadesSeleccionadas)..add(id);
    widget.onChanged(newList, _notasEliminacion);
  }

  final Map<int, String> _notasEliminacion = {};

  void _removeActividad(int id) {
    // Solo pedir nota si la actividad ya existía en la inspección guardada
    final yaEstabaGuardada = widget.actividadesDeInspeccion.contains(id);
    
    if (yaEstabaGuardada) {
      _mostrarDialogoNotaEliminacion(id);
    } else {
      // Si se acaba de agregar en esta sesión, se quita sin preguntar
      setState(() {
        final newList = List<int>.from(widget.actividadesSeleccionadas)..remove(id);
        widget.onChanged(newList, _notasEliminacion);
      });
    }
  }

  void _mostrarDialogoNotaEliminacion(int id) {
    final TextEditingController notaController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(PhosphorIcons.trash(), color: Colors.red),
            SizedBox(width: 10),
            Text('Razón de Eliminación'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Es obligatorio indicar por qué se elimina esta actividad:'),
              const SizedBox(height: 15),
              TextFormField(
                controller: notaController,
                maxLines: null, // Permite expansión infinita
                minLines: 3,    // Altura inicial
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Escriba la razón aquí...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La razón es obligatoria';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _notasEliminacion[id] = notaController.text.trim();
                  final newList = List<int>.from(widget.actividadesSeleccionadas)..remove(id);
                  widget.onChanged(newList, _notasEliminacion);
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor, // Branding
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar Eliminación'),
          ),
        ],
      ),
    );
  }

  // Getter para que el padre pueda obtener las notas si es necesario, 
  // aunque lo ideal es pasarlo por el callback.
  // Vamos a modificar el callback del widget para pasar también las notas de eliminación.
  
  @override
  Widget build(BuildContext context) {
    // ... resto del build ...
    final provider = Provider.of<ActividadesProvider>(context);

    // Mapear IDs a Modelos para mostrar chips
    final selectedModels = widget.actividadesSeleccionadas.map((id) {
      return provider.obtenerPorId(id) ?? ActividadEstandarModel(id: id, actividad: 'Desconocido ($id)', activo: false);
    }).toList();

    final hasSystems = widget.sistemasSeleccionados.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: TextFormField(
            controller: _searchController,
            focusNode: _focusNode,
            enabled: hasSystems, // ✅ Deshabilitar si no hay sistemas
            decoration: InputDecoration(
              labelText: hasSystems 
                ? 'Buscar y agregar actividad...' 
                : 'Seleccione un sistema primero para buscar actividades',
              labelStyle: TextStyle(
                color: hasSystems ? null : Colors.orange.shade700,
                fontWeight: hasSystems ? null : FontWeight.bold,
              ),
              prefixIcon: Icon(
                PhosphorIcons.magnifyingGlass(),
                color: hasSystems ? null : Colors.grey,
              ),
              suffixIcon: _searchController.text.isNotEmpty 
                ? IconButton(
                    icon: Icon(PhosphorIcons.x()), 
                    onPressed: () { 
                      _searchController.clear();
                      _overlayEntry?.markNeedsBuild();
                    }) 
                : null,
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: widget.showError 
                    ? Colors.red 
                    : (hasSystems ? Colors.grey : Colors.orange),
                  width: widget.showError ? 2 : 1,
                ),
              ),
              fillColor: widget.showError 
                ? Colors.red.withOpacity(0.05) 
                : (hasSystems ? null : Colors.orange.withOpacity(0.05)),
              filled: !hasSystems || widget.showError,
            ),
            onChanged: (_) {
              if (_overlayEntry == null) {
                _showOverlay();
              } else {
                _overlayEntry!.markNeedsBuild();
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        if (selectedModels.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedModels.map((act) {
              final isLocked = widget.actividadesBloqueadas.contains(act.id);
              
              return Chip(
                label: Text(act.actividad),
                onDeleted: isLocked ? null : () => _removeActividad(act.id),
                deleteIcon: isLocked ? Icon(PhosphorIcons.lock(), size: 16, color: Colors.grey) : Icon(PhosphorIcons.x(), size: 18),
                backgroundColor: isLocked ? Colors.grey.shade100 : Colors.blue.shade50,
                labelStyle: TextStyle(color: isLocked ? Colors.grey.shade600 : Colors.blue.shade900),
              );
            }).toList(),
          ),
          
        if (selectedModels.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Ninguna actividad seleccionada.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
