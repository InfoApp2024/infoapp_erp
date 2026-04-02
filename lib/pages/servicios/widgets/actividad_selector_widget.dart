import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import '../models/actividad_estandar_model.dart';
import '../models/servicio_model.dart';
import '../services/actividades_service.dart';

class ActividadSelectorWidget extends StatefulWidget {
  final ServicioModel servicio;
  final Function(ActividadEstandarModel?) onChanged;
  final bool enabled;

  const ActividadSelectorWidget({
    super.key,
    required this.servicio,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<ActividadSelectorWidget> createState() =>
      _ActividadSelectorWidgetState();
}

class _ActividadSelectorWidgetState extends State<ActividadSelectorWidget> {
  ActividadEstandarModel? _actividadSeleccionada;
  bool _isLoading = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Cargar datos despué©s del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inicializarDatos();
      }
    });
  }

  @override
  void dispose() {
    _actividadSeleccionada = null;
    super.dispose();
  }

  Future<void> _inicializarDatos() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final actividadesService = context.read<ActividadesService>();

      // Cargar actividades si no están cargadas
      if (actividadesService.actividades.isEmpty &&
          !actividadesService.isLoading) {
        await actividadesService.cargarActividades();
      }

      // Establecer actividad seleccionada si existe
      if (mounted && widget.servicio.actividadId != null) {
        final actividad = actividadesService.obtenerActividadPorId(
          widget.servicio.actividadId,
        );

        if (mounted) {
          setState(() {
            _actividadSeleccionada = actividad;
            _hasInitialized = true;
          });
        }
      } else if (mounted) {
        setState(() {
          _hasInitialized = true;
        });
      }
    } catch (e) {
      // Error inicializando datos: $e
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verificar si el provider existe
    final actividadesService = context.watch<ActividadesService?>();

    if (actividadesService == null) {
      return _buildErrorWidget('Servicio no disponible');
    }

    // Si está cargando inicialmente
    if (!_hasInitialized ||
        (_isLoading && actividadesService.actividades.isEmpty)) {
      return _buildLoadingWidget();
    }

    // Si hay error
    if (actividadesService.error.isNotEmpty) {
      return _buildErrorWidget(actividadesService.error);
    }

    final actividades = actividadesService.actividades;
    // Permisos del mé³dulo Servicios y subgrupo especé­fico "Actividades"

    return Column(
      children: [
        // Campo de béºsqueda (Abajo y Aislado)
        Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  widget.enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            ),
            color: Colors.white,
          ),
          child: DropdownSearch<ActividadEstandarModel>(
            // Configuracié³n del popup actualizada para v6.x
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: "Buscar actividad...",
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
              ),
              itemBuilder:
                  (context, item, isDisabled, isSelected) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(
                      PhosphorIcons.checkCircle(),
                      size: 16,
                      color: item.activo ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      item.actividad,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              menuProps: const MenuProps(
                backgroundColor: Colors.white,
                elevation: 5,
              ),
            ),
            // Configuracié³n de items actualizada
            items:
                (filter, infiniteScrollProps) async =>
                    actividades.where((a) => a.activo).toList(),
            selectedItem: _actividadSeleccionada,
            onChanged:
                widget.enabled && !_isLoading
                    ? (ActividadEstandarModel? newValue) {
                      if (mounted) {
                        setState(() {
                          _actividadSeleccionada = newValue;
                        });
                        widget.onChanged(newValue);
                      }
                    }
                    : null,
            // Configuracié³n del decorador actualizada
            decoratorProps: DropDownDecoratorProps(
              decoration: InputDecoration(
                hintText:
                    actividades.isEmpty
                        ? 'Sin actividades'
                        : 'Seleccionar actividad',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ), // Ajustado
                isDense: false, // Permitir que se centre verticalmente mejor
              ),
            ),
            // Builder para el item seleccionado
            dropdownBuilder: (context, selectedItem) {
              // Evitar texto duplicado cuando no hay seleccié³n
              if (selectedItem == null) {
                return const SizedBox.shrink();
              }
              return Row(
                children: [
                  Icon(
                    PhosphorIcons.checkCircle(),
                    size: 16,
                    color: selectedItem.activo ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedItem.actividad,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
            // Funcié³n de comparacié³n para determinar igualdad
            compareFn: (item1, item2) {
              return item1.id == item2.id;
            },
            // Funcié³n de filtro para la béºsqueda
            filterFn: (item, filter) {
              return item.actividad.toLowerCase().contains(
                filter.toLowerCase(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(PhosphorIcons.warningCircle(), size: 16, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.enabled) ...[
              IconButton(
                icon: Icon(
                  PhosphorIcons.arrowsClockwise(),
                  size: 16,
                  color: Colors.red,
                ),
                onPressed: _inicializarDatos,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
