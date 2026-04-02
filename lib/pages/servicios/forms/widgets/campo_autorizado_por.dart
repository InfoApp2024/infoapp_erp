import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ NUEVO
import '../../models/funcionario_model.dart';
import '../../services/servicios_api_service.dart';

class CampoAutorizadoPor extends StatefulWidget {
  final int? autorizadoPor;
  final Function(int?) onChanged;
  final String? Function(int?)? validator;
  final bool enabled;
  final String? empresa;
  final int? clienteId; // ✅ NUEVO: Filtro por cliente

  const CampoAutorizadoPor({
    super.key,
    required this.autorizadoPor,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.empresa,
    this.clienteId, // ✅ NUEVO
  });

  @override
  State<CampoAutorizadoPor> createState() => _CampoAutorizadoPorState();
}

class _CampoAutorizadoPorState extends State<CampoAutorizadoPor> {
  List<FuncionarioModel> _funcionarios = [];
  bool _isLoading = false;
  String? _error;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  bool _showAllOptions = false;

  @override
  void initState() {
    super.initState();
    _cargarFuncionarios();
  }

  @override
  void didUpdateWidget(covariant CampoAutorizadoPor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autorizadoPor != widget.autorizadoPor) {
      _searchController.clear();
      _showAllOptions = false;
    }
    if (widget.clienteId != oldWidget.clienteId) {
      _cargarFuncionarios();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarFuncionarios() async {
    if (widget.clienteId == null) {
      if (mounted) {
        setState(() {
          _funcionarios = [];
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final funcionarios = await ServiciosApiService.listarFuncionarios(
        empresa: widget.empresa,
        clienteId: widget.clienteId,
      );

      if (mounted) {
        setState(() => _funcionarios = funcionarios);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error cargando funcionarios: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int? _getValidValue() {
    if (widget.autorizadoPor == null) return null;
    final exists = _funcionarios.any(
      (f) => f.id == widget.autorizadoPor && f.activo,
    );
    return exists ? widget.autorizadoPor : null;
  }

  Widget _buildSearchableDropdown() {
    final funcionariosUnicos = <int, FuncionarioModel>{};
    for (var funcionario in _funcionarios) {
      if (funcionario.activo && funcionario.id > 0) {
        funcionariosUnicos[funcionario.id] = funcionario;
      }
    }

    return SearchableDropdown(
      value: _getValidValue(),
      items: funcionariosUnicos.values.toList(),
      onChanged:
          widget.enabled && widget.clienteId != null && !_isLoading
              ? (value) {
                _searchController.clear();
                _showAllOptions = false;
                widget.onChanged(value);
              }
              : null,
      focusNode: _searchFocusNode,
      searchController: _searchController,
      isLoading: _isLoading,
      prefixIcon: Icon(Icons.person_pin, color: Theme.of(context).primaryColor),
      labelText: 'Autorizado Por',
      validator: widget.validator,
      showAllOptions: _showAllOptions,
      onShowAllOptionsChanged: (show) => setState(() => _showAllOptions = show),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildSearchableDropdown();
  }
}

class SearchableDropdown extends StatefulWidget {
  final int? value;
  final List<FuncionarioModel> items;
  final ValueChanged<int?>? onChanged;
  final FocusNode focusNode;
  final TextEditingController searchController;
  final bool isLoading;
  final Widget prefixIcon;
  final String labelText;
  final String? Function(int?)? validator;
  final bool showAllOptions;
  final ValueChanged<bool>? onShowAllOptionsChanged;

  const SearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.focusNode,
    required this.searchController,
    required this.isLoading,
    required this.prefixIcon,
    required this.labelText,
    this.validator,
    this.showAllOptions = false,
    this.onShowAllOptionsChanged,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _showOptions = false;
  bool _isProcessingSelection =
      false; // NUEVO: Flag para controlar la selección
  // NUEVO: FocusNode dedicado para el buscador dentro del overlay
  final FocusNode _overlaySearchFocusNode = FocusNode();

  // Helper: normaliza texto para comparaciones (minusculas y sin acentos)
  String _normalize(String input) {
    final lower = input.toLowerCase();
    return lower
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ä', 'a')
        .replaceAll('ë', 'e')
        .replaceAll('ï', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('â', 'a')
        .replaceAll('ê', 'e')
        .replaceAll('î', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('û', 'u');
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
    _overlaySearchFocusNode.addListener(
      _handleOverlayFocusChange,
    ); // Nuevo listener
    widget.searchController.addListener(_handleSearchChange);
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Ejecutar operaciones de Overlay después del frame para evitar errores de aserción en Web
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.showAllOptions != oldWidget.showAllOptions ||
          widget.items != oldWidget.items ||
          widget.isLoading != oldWidget.isLoading) {
        if (widget.showAllOptions) {
          _showOptionsOverlay();
        } else if (!_isProcessingSelection) {
          // Si los ítems cambiaron y el overlay está abierto, refrescarlo
          if (_overlayEntry != null) {
            _overlayEntry!.markNeedsBuild();
          }

          if (!widget.showAllOptions && oldWidget.showAllOptions) {
            _hideOptionsOverlay();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    _overlaySearchFocusNode.removeListener(
      _handleOverlayFocusChange,
    ); // Limpiar listener
    widget.searchController.removeListener(_handleSearchChange);
    _overlaySearchFocusNode.dispose();
    _hideOptionsOverlay(isDisposing: true);
    super.dispose();
  }

  void _handleFocusChange() {
    // Si el foco vuelve al campo principal (ej. al cerrar overlay), mantener abierto si es necesario?
    // No, normalmente si tiene foco principal, mostramos overlay.
    if (widget.focusNode.hasFocus) {
      if (widget.onChanged == null) return;
      _showOptionsOverlay();
    } else {
      // Foco perdido del principal. Verificamos si se fue al overlay.
      _checkAndCloseOverlay();
    }
  }

  void _handleOverlayFocusChange() {
    if (!_overlaySearchFocusNode.hasFocus) {
      // Foco perdido del overlay. Verificamos si volvió al principal o se fue fuera.
      _checkAndCloseOverlay();
    }
  }

  void _checkAndCloseOverlay() {
    if (_isProcessingSelection) return;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      // Si NINGUNO de los dos tiene foco, cerrar.
      if (!widget.focusNode.hasFocus && !_overlaySearchFocusNode.hasFocus) {
        _hideOptionsOverlay();
      }
    });
  }

  void _handleSearchChange() {
    if (widget.focusNode.hasFocus) {
      if (_overlayEntry == null) {
        _showOptionsOverlay();
      } else {
        // Refrescar overlay después del frame para evitar errores de aserción
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOverlay());
      }
    }
  }

  void _refreshOverlay() {
    if (!mounted || _overlayEntry == null) return;
    try {
      _overlayEntry?.markNeedsBuild();
    } catch (e) {
      // Ignorar errores si el overlay ya se está redibujando o ya no es válido
    }
  }

  void _showOptionsOverlay() {
    if (!mounted ||
        _overlayEntry != null ||
        _isProcessingSelection ||
        widget.onChanged == null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // ✅ CORRECCIÓN: Obtener el ancho del widget ANTES del builder del Overlay
        // Usar 'this.context' para el RenderBox original, no el 'context' del builder
        final renderBox = this.context.findRenderObject() as RenderBox?;
        final size = renderBox?.size;
        final screenWidth = MediaQuery.of(context).size.width;

        // Usar el ancho del campo o un máximo del 90% de la pantalla
        final overlayWidth = size != null ? size.width : screenWidth * 0.9;

        return Positioned(
          width: overlayWidth.clamp(200.0, screenWidth * 0.9),
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 48),
            child: Material(
              elevation: 4.0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 320,
                  maxWidth: overlayWidth.clamp(200.0, screenWidth * 0.9),
                ),
                child: ClipRect(child: _buildOverlayContent()),
              ),
            ),
          ),
        );
      },
    );

    try {
      final overlay = Overlay.of(context);
      overlay.insert(_overlayEntry!);
      if (mounted) setState(() => _showOptions = true);

      // Mover el foco al campo de búsqueda del overlay
      // ✅ MEJORA WEB: Usar un delay mayor en web para evitar conflictos con el motor de punteros
      if (kIsWeb) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _overlaySearchFocusNode.canRequestFocus) {
            _overlaySearchFocusNode.requestFocus();
          }
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _overlaySearchFocusNode.canRequestFocus) {
            _overlaySearchFocusNode.requestFocus();
          }
        });
      }
    } catch (e) {
      _overlayEntry = null;
    }
  }

  Widget _buildOverlayContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Barra de búsqueda similar a CampoEquipo
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            controller: widget.searchController,
            autofocus: true,
            focusNode: _overlaySearchFocusNode,
            onChanged: (_) {
              // Refrescar listado mientras se escribe
              if (mounted) setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Buscar funcionario...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon:
                  widget.searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          widget.searchController.clear();
                          // Forzar refresco de la lista
                          if (mounted) setState(() {});
                        },
                      )
                      : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        // Lista de opciones
        Expanded(child: _buildOptionsList()),
      ],
    );
  }

  void _hideOptionsOverlay({bool isDisposing = false}) {
    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
      } catch (e) {
        // Ignorar si ya fue removido o está en estado inválido
      }
      _overlayEntry = null;
      if (mounted && !isDisposing) {
        setState(() => _showOptions = false);
      }
      if (widget.onShowAllOptionsChanged != null) {
        widget.onShowAllOptionsChanged!(false);
      }
    }
  }

  List<FuncionarioModel> _getFilteredItems() {
    if (widget.showAllOptions) return widget.items;

    final searchText = widget.searchController.text.trim();
    if (searchText.isEmpty) {
      // Sin texto: mostrar un subconjunto para no abrumar (p. ej., primeros 50)
      return widget.items.take(50).toList();
    }

    final tokens =
        _normalize(
          searchText,
        ).split(RegExp(r"\s+")).where((t) => t.isNotEmpty).toList();

    return widget.items.where((f) {
      final haystack = _normalize(f.descripcion);
      // Coincide si TODOS los tokens están presentes en la descripción
      for (final token in tokens) {
        if (!haystack.contains(token)) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildOptionsList() {
    final filteredItems = _getFilteredItems();

    if (widget.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.showAllOptions
              ? 'No hay funcionarios disponibles'
              : (widget.searchController.text.isEmpty
                  ? 'Escribe para buscar o desplázate'
                  : 'Sin resultados para tu búsqueda'),
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final funcionario = filteredItems[index];
        return _buildOptionItem(funcionario);
      },
    );
  }

  Widget _buildOptionItem(FuncionarioModel funcionario) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            () => _handleOptionSelection(
              funcionario,
            ), // MEJORADO: Método separado
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Text(
            funcionario.descripcion,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  // NUEVO: Método específico para manejar la selección
  void _handleOptionSelection(FuncionarioModel funcionario) async {
    if (_isProcessingSelection) return; // Prevenir múltiples clics rápidos

    setState(() => _isProcessingSelection = true);

    try {
      // Ejecutar el callback de cambio
      if (widget.onChanged != null) {
        widget.onChanged!(funcionario.id);
      }

      // Pequeño delay para asegurar que el cambio se procese
      await Future.delayed(const Duration(milliseconds: 50));

      // Cerrar el overlay
      _hideOptionsOverlay();
    } finally {
      // Resetear el flag después de un breve delay
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _isProcessingSelection = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final funcionarioSeleccionado =
        widget.value != null
            ? widget.items.firstWhere(
              (f) => f.id == widget.value,
              orElse:
                  () => FuncionarioModel(
                    id: 0,
                    nombre: 'Seleccione un funcionario',
                    activo: true,
                  ),
            )
            : null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.searchController,
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText,
              prefixIcon: widget.prefixIcon,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 12,
              ),
              // ✅ MEJORA UI: Icono de limpiar o flecha (Solo si es editable)
              suffixIcon:
                  widget.onChanged == null
                      ? null
                      : (widget.value != null
                          ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            tooltip: 'Limpiar selección',
                            onPressed: () {
                              widget.searchController.clear();
                              if (widget.onChanged != null) {
                                widget.onChanged!(null);
                              }
                            },
                          )
                          : const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          )),
            ),
            onTap: _showOptionsOverlay,
            readOnly: widget.onChanged == null || _showOptions,
            validator:
                widget.validator != null
                    ? (_) => widget.validator!(widget.value)
                    : null,
          ),
          if (widget.value != null && !_showOptions)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8, right: 16),
              child: Text(
                funcionarioSeleccionado?.descripcion ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
