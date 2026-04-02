import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/main.dart';
import 'package:provider/provider.dart';
import '../models/sistema_model.dart';
import '../providers/sistemas_provider.dart';

class SelectorSistemas extends StatefulWidget {
  final List<int> sistemasSeleccionados;
  final Function(List<int>) onChanged;
  final bool enabled;
  final bool showError;

  const SelectorSistemas({
    super.key,
    required this.sistemasSeleccionados,
    required this.onChanged,
    this.enabled = true,
    this.showError = false,
  });

  @override
  State<SelectorSistemas> createState() => _SelectorSistemasState();
}

class _SelectorSistemasState extends State<SelectorSistemas> {

  // Dropdown state
  int? _sistemaFocoId; // El sistema seleccionado en el dropdown (para agregar)

  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Cargar sistemas si no están cargados
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SistemasProvider>(context, listen: false);
      if (provider.sistemas.isEmpty) {
        provider.cargarSistemas();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Getters
  SistemaModel? get _sistemaFoco {
    if (_sistemaFocoId == null) return null;
    final provider = Provider.of<SistemasProvider>(context, listen: false);
    return provider.obtenerSistemaPorId(_sistemaFocoId!);
  }

  void _handleAddtoInspection() {
    if (_sistemaFocoId != null &&
        !widget.sistemasSeleccionados.contains(_sistemaFocoId)) {
      final newList = List<int>.from(widget.sistemasSeleccionados)
        ..add(_sistemaFocoId!);
      widget.onChanged(newList);

      // Feedback visual opcional
      // Feedback visual opcional
      if (mounted) {
        MyApp.showSnackBar(
          'Sistema "${_sistemaFoco?.nombre}" agregado',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  void _handleRemoveFromInspection(int id) {
    final newList = List<int>.from(widget.sistemasSeleccionados)..remove(id);
    widget.onChanged(newList);
  }

  Widget _buildSuffixButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Solo dejamos el botón de expansión si es necesario,
        // o lo quitamos si ya no hay gestión.
        // En este caso, el caretDown del dropdown es suficiente.
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SistemasProvider>(
      builder: (context, provider, _) {
        return Card(
          shape: widget.showError 
            ? RoundedRectangleBorder(
                side: const BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.gear(),
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sistemas a Inspeccionar *',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Seleccione o administre los sistemas.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    _buildSuffixButtons(),
                  ],
                ),
                const SizedBox(height: 8),

                // Dropdown Area
                _SearchableDropdownSistemas(
                  value: _sistemaFocoId,
                  items: provider.sistemas,
                  onChanged: (val) {
                    setState(() {
                      _sistemaFocoId = val;
                      _searchController.clear();
                    });
                    // ✅ SELECCIÓN AUTOMÁTICA
                    if (val != null) {
                      _handleAddtoInspection();
                    }
                  },
                  focusNode: _searchFocusNode,
                  searchController: _searchController,
                  isLoading: provider.isLoading,
                  labelText: 'Buscar Sistema...',
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                  suffixButtons: Icon(
                    PhosphorIcons.caretDown(),
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 8),

                // Chips de seleccionados
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      widget.sistemasSeleccionados.map((id) {
                        final sys = provider.obtenerSistemaPorId(id);
                        return Chip(
                          label: Text(sys?.nombre ?? 'Desconocido'),
                          onDeleted: () => _handleRemoveFromInspection(id),
                          avatar: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              (sys?.nombre ?? '?')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),

                if (widget.sistemasSeleccionados.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ No hay sistemas seleccionados',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// ADAPTED SEARCHABLE DROPDOWN FOR SISTEMAS
// =============================================================================

class _SearchableDropdownSistemas extends StatefulWidget {
  final int? value;
  final List<SistemaModel> items;
  final ValueChanged<int?>? onChanged;
  final FocusNode focusNode;
  final TextEditingController searchController;
  final bool isLoading;
  final Widget suffixButtons;
  final Widget prefixIcon;
  final String labelText;

  const _SearchableDropdownSistemas({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.focusNode,
    required this.searchController,
    required this.isLoading,
    required this.suffixButtons,
    required this.prefixIcon,
    required this.labelText,
  });

  @override
  State<_SearchableDropdownSistemas> createState() =>
      _SearchableDropdownSistemasState();
}

class _SearchableDropdownSistemasState
    extends State<_SearchableDropdownSistemas> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _showOptions = false;
  final FocusNode _overlaySearchFocusNode = FocusNode();


  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
    widget.searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    widget.searchController.removeListener(_handleSearchChange);
    _overlaySearchFocusNode.dispose();
    _hideOptionsOverlay(isDisposing: true);
    super.dispose();
  }

  void _handleFocusChange() {
    if (widget.focusNode.hasFocus) {
      _showOptionsOverlay();
    } else {
      // Delay closing
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_overlaySearchFocusNode.hasFocus) {
          _hideOptionsOverlay();
        }
      });
    }
  }

  void _handleSearchChange() {
    if (widget.focusNode.hasFocus) {
      if (_overlayEntry == null) {
        _showOptionsOverlay();
      } else if (mounted) {
        _overlayEntry!.markNeedsBuild(); // Refresh overlay
      }
    }
  }

  void _showOptionsOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            width:
                MediaQuery.of(context).size.width *
                0.9, // Adjust width as needed
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 50),
              child: Material(
                elevation: 4,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: widget.searchController,
                          focusNode: _overlaySearchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Buscar...',
                            prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                          ),
                          onChanged: (_) => _overlayEntry?.markNeedsBuild(),
                        ),
                      ),
                      Expanded(child: _buildList()),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showOptions = true);
  }

  void _hideOptionsOverlay({bool isDisposing = false}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted && !isDisposing) {
      setState(() => _showOptions = false);
    }
  }

  Widget _buildList() {
    final search = widget.searchController.text.toLowerCase();
    final filtered =
        widget.items
            .where((s) => (s.nombre ?? '').toLowerCase().contains(search))
            .toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No encontrado'),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return ListTile(
          title: Text(item.nombre ?? '-'),
          onTap: () {
            widget.onChanged!(item.id);
            _hideOptionsOverlay();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        widget.value != null
            ? widget.items.firstWhere(
              (i) => i.id == widget.value,
              orElse: () => SistemaModel(id: 0, nombre: 'Seleccione...'),
            )
            : null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller:
                widget
                    .searchController, // Usamos controller para visualizar tambien
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixButtons, // Important
              border: const OutlineInputBorder(),
            ),
            readOnly:
                true, // Prevent typing directly, force use of overlay? or allow?
            // If we allow typing, we need to sync searchController.
            // For consistency with CampoAutorizadoPor, it seems readOnly when not searching?
            // Actually, the original implementation allowed typing in main field IF overlay wasn't fully covering.
            // But here I simplified. Let's make it readOnly and show selected text.
            // WAIT: searchController shows the query.
            // We want to show the SELECTED VALUE.
          ),
          if (selected != null && !_showOptions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Seleccionado: ${selected.nombre}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
