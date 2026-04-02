import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../models/equipo_model.dart';
import '../../services/servicios_api_service.dart';
// Se elimina la dependencia del módulo de Equipos para aprovechar
// la versión con caché offline del servicio de Servicios.

/// Widget especializado para la selección de equipos con búsqueda
class CampoEquipo extends StatefulWidget {
  final int? equipoSeleccionado;
  final int? clienteId; // ✅ NUEVO: Filtro por cliente
  final Function(EquipoModel?) onChanged;
  final String? Function(int?)? validator;
  final bool enabled;

  const CampoEquipo({
    super.key,
    required this.equipoSeleccionado,
    this.clienteId, // ✅ NUEVO
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<CampoEquipo> createState() => _CampoEquipoState();
}

class _CampoEquipoState extends State<CampoEquipo> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<EquipoModel> _equipos = [];
  List<EquipoModel> _equiposFiltrados = [];
  bool _isLoading = false;
  String? _error; // ✅ Add missing variable

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarEquipos();
  }

  @override
  void didUpdateWidget(covariant CampoEquipo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clienteId != widget.clienteId) {
      // Si el cliente cambia, recargar equipos y limpiar selección si es necesario
      _cargarEquipos();
      // Si el equipo seleccionado actualmente no pertenece al nuevo cliente, 
      // esto se manejará en el form principal o aquí si quisiéramos ser agresivos.
      // Por ahora solo recargamos la lista.
    }
  }

  Widget _buildDropdownEquiposSearch() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownSearch<EquipoModel>(
        items: (filter, loadProps) => _equipos, 
        selectedItem: _getEquipoSeleccionado(),
        // ✅ Disable if no client is selected
        enabled: widget.enabled && widget.clienteId != null,
        compareFn: (item, selectedItem) => item.id == selectedItem.id,
        // Texto amigable para cada equipo (nombre y placa opcional)
        itemAsString: (item) => _equipoLabel(item),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Filtrar por equipo, código o empresa',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          constraints: const BoxConstraints(maxHeight: 300),
          itemBuilder: (context, item, isDisabled, isSelected) => ListTile(
            dense: true,
            title: Text(
              _equipoLabel(item),
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        filterFn: (item, filter) {
          if (filter.isEmpty) return true;
          final f = filter.toLowerCase();
          final nombre = item.nombre.toLowerCase();
          final placa = item.placa?.toLowerCase() ?? '';
          final codigo = item.codigo?.toLowerCase() ?? '';
          final empresa = item.nombreEmpresa?.toLowerCase() ?? '';
          final marca = item.marca?.toLowerCase() ?? '';
          final modelo = item.modelo?.toLowerCase() ?? '';
          return nombre.contains(f) ||
              placa.contains(f) ||
              codigo.contains(f) ||
              empresa.contains(f) ||
              marca.contains(f) ||
              modelo.contains(f);
        },
        decoratorProps: DropDownDecoratorProps(
          decoration: InputDecoration(
            labelText: 'Seleccionar Equipo',
            prefixIcon: Icon(
              Icons.precision_manufacturing,
              color: Theme.of(context).primaryColor,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        dropdownBuilder: (context, selectedItem) {
          if (selectedItem == null) return const SizedBox.shrink();
          return Text(
            _equipoLabel(selectedItem),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          );
        },
        validator: (equipo) {
          if (widget.validator != null) {
            return widget.validator!(equipo?.id);
          }
          return null;
        },
        onChanged: (equipo) {
          widget.onChanged(equipo);
        },
      ),
    );
  }


  // Formatea el texto que se muestra para cada equipo
  String _equipoLabel(EquipoModel e) {
    final placa = (e.placa != null && e.placa!.isNotEmpty) ? ', placa: ${e.placa!}' : '';
    return '${e.nombre}$placa';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarEquipos() async {
    // ✅ Validar si hay cliente seleccionado
    if (widget.clienteId == null) {
      if (mounted) {
        setState(() {
          _equipos = [];
          _equiposFiltrados = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Usar el servicio unificado que ya maneja caché
      final equipos = await ServiciosApiService.listarEquipos(
        clienteId: widget.clienteId,
      );

      if (!mounted) return;

      // Filtrar duplicados por ID
      final uniqueEquipos = <EquipoModel>[];
      final ids = <int>{};

      for (var e in equipos) {
        if (!ids.contains(e.id)) {
          uniqueEquipos.add(e);
          ids.add(e.id);
        }
      }

      setState(() {
        _equipos = uniqueEquipos;
        _equiposFiltrados = List<EquipoModel>.from(uniqueEquipos);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar equipos: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filtrarEquipos(String busqueda) {
    setState(() {
      if (busqueda.trim().isEmpty) {
        _equiposFiltrados = List<EquipoModel>.from(_equipos);
      } else {
        _equiposFiltrados =
            _equipos.where((equipo) {
              final nombre = equipo.nombre.toLowerCase();
              final placa = equipo.placa?.toLowerCase() ?? '';
              final codigo = equipo.codigo?.toLowerCase() ?? '';
              final empresa = equipo.nombreEmpresa?.toLowerCase() ?? '';
              final marca = equipo.marca?.toLowerCase() ?? '';
              final modelo = equipo.modelo?.toLowerCase() ?? '';
              final busquedaLower = busqueda.toLowerCase().trim();

              return nombre.contains(busquedaLower) ||
                  placa.contains(busquedaLower) ||
                  codigo.contains(busquedaLower) ||
                  empresa.contains(busquedaLower) ||
                  marca.contains(busquedaLower) ||
                  modelo.contains(busquedaLower);
            }).toList();
      }
    });
  }

  int? _getValidValue() {
    if (widget.equipoSeleccionado != null &&
        _equipos.any((e) => e.id == widget.equipoSeleccionado)) {
      return widget.equipoSeleccionado;
    }
    return null;
  }

  EquipoModel? _getEquipoSeleccionado() {
    if (widget.equipoSeleccionado != null) {
      return _equipos.firstWhere(
        (e) => e.id == widget.equipoSeleccionado,
        orElse: () => _equipos.first,
      );
    }
    return null;
  }

  void _onEquipoSeleccionado(int? equipoId) {
    if (equipoId != null) {
      final equipo = _equipos.firstWhere(
        (e) => e.id == equipoId,
        orElse: () => _equipos.first,
      );
      widget.onChanged(equipo);
    } else {
      widget.onChanged(null);
    }
  }

  Widget _buildCampoBusqueda() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Buscar equipo...',
          hintText: 'Nombre, placa, empresa, marca o modelo',
          prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
          suffixIcon:
              _equiposFiltrados.length != _equipos.length
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filtrarEquipos('');
                      FocusScope.of(context).unfocus();
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        enabled: widget.enabled,
        onChanged: _filtrarEquipos,
      ),
    );
  }

  Widget _buildContadorResultados() {
    if (_equiposFiltrados.length == _equipos.length) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Mostrando ${_equiposFiltrados.length} de ${_equipos.length} equipos',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownEquipos() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<int>(
        // Evita el assert cuando el filtro excluye el valor seleccionado
        initialValue: _getValidValue(),
        decoration: InputDecoration(
          labelText: 'Seleccionar Equipo',
          prefixIcon: Icon(
            Icons.precision_manufacturing,
            color: Theme.of(context).primaryColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        isExpanded: true,
        items:
            _equipos.map((equipo) {
              return DropdownMenuItem<int>(
                value: equipo.id,
                child: Text(
                  equipo.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
        onChanged: widget.enabled ? _onEquipoSeleccionado : null,
        validator: (value) {
          if (widget.validator != null) {
            return widget.validator!(value);
          }
          return null;
        },
        menuMaxHeight: 300,
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _buildItemEquipo(EquipoModel equipo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Línea principal: Nombre + Placa
        Row(
          children: [
            Expanded(
              child: Text(
                equipo.nombre,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (equipo.placa != null && equipo.placa!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                ),
                child: Text(
                  equipo.placa!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),

        // Línea secundaria: Marca/Modelo + Empresa
        const SizedBox(height: 2),
        Row(
          children: [
            if (equipo.marca != null || equipo.modelo != null) ...[
              Expanded(
                child: Text(
                  [
                    equipo.marca,
                    equipo.modelo,
                  ].where((s) => s != null && s.isNotEmpty).join(' - '),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (equipo.nombreEmpresa != null &&
                equipo.nombreEmpresa!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                equipo.nombreEmpresa!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMensajeSinResultados() {
    if (_equiposFiltrados.isNotEmpty || _equipos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.search_off, color: Colors.orange.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se encontraron equipos que coincidan con la búsqueda',
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformacionEquipoSeleccionado() {
    final equipoSeleccionado = _getEquipoSeleccionado();
    if (equipoSeleccionado == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Información del Equipo Seleccionado',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildInfoRow('Nombre:', equipoSeleccionado.nombre),
          if (equipoSeleccionado.placa != null &&
              equipoSeleccionado.placa!.isNotEmpty)
            _buildInfoRow('Placa:', equipoSeleccionado.placa!),
          if (equipoSeleccionado.marca != null &&
              equipoSeleccionado.marca!.isNotEmpty)
            _buildInfoRow('Marca:', equipoSeleccionado.marca!),
          if (equipoSeleccionado.modelo != null &&
              equipoSeleccionado.modelo!.isNotEmpty)
            _buildInfoRow('Modelo:', equipoSeleccionado.modelo!),
          if (equipoSeleccionado.nombreEmpresa != null &&
              equipoSeleccionado.nombreEmpresa!.isNotEmpty)
            _buildInfoRow('Empresa:', equipoSeleccionado.nombreEmpresa!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Cargando equipos...'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown de equipos (DropdownSearch)
        _buildDropdownEquiposSearch(),

        // Mensaje sin resultados
        _buildMensajeSinResultados(),

        // Información del equipo seleccionado
        _buildInformacionEquipoSeleccionado(),
      ],
    );
  }
}
