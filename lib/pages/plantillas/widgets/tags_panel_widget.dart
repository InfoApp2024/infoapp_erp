import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/plantilla_provider.dart';
import '../models/tag_model.dart';
import '../models/tag_category_model.dart';

class TagsPanelWidget extends StatefulWidget {
  final String modulo;
  final Function(String)? onTagSelected;

  const TagsPanelWidget({
    super.key,
    this.modulo = 'servicios',
    this.onTagSelected,
  });

  @override
  State<TagsPanelWidget> createState() => _TagsPanelWidgetState();
}

class _TagsPanelWidgetState extends State<TagsPanelWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantillaProvider>().loadTags(modulo: widget.modulo);
    });
  }

  @override
  void didUpdateWidget(TagsPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modulo != widget.modulo) {
      context.read<PlantillaProvider>().loadTags(modulo: widget.modulo);
    }
  }

  void _copyTag(String tag) {
    final normalized = _normalizeTag(tag);

    if (widget.onTagSelected != null) {
      widget.onTagSelected!(normalized);
      return;
    }

    Clipboard.setData(ClipboardData(text: normalized));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tag copiado: $normalized'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlantillaProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingTags) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.tagsError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar tags',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => provider.loadTags(modulo: widget.modulo),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        if (provider.tagCategories.isEmpty) {
          return const Center(
            child: Text('No hay tags disponibles'),
          );
        }

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.label, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tags Disponibles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Toca un tag para insertarlo',
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            _buildSearchBar(),

            // Lista de categorías filtradas
            Expanded(
              child: _buildFilteredList(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: Theme.of(context).primaryColor,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar tags...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildFilteredList(PlantillaProvider provider) {
    if (_searchQuery.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: provider.tagCategories.length,
        itemBuilder: (context, index) {
          final category = provider.tagCategories[index];
          final filteredTags = category.tags.where((tag) => _isUserFriendlyTag(tag.tag)).toList();
          
          if (filteredTags.isEmpty) return const SizedBox.shrink();
          
          return _CategoryExpansionTile(
            category: category.copyWith(tags: filteredTags),
            onTagTap: _copyTag,
          );
        },
      );
    }

    // Filtrar manteniendo categorías
    final List<TagCategory> filteredCategories = [];
    for (var cat in provider.tagCategories) {
      final matchingTags = cat.tags.where((tag) {
        final isMatch = tag.tag.toLowerCase().contains(_searchQuery) ||
                        tag.description.toLowerCase().contains(_searchQuery);
        return isMatch && _isUserFriendlyTag(tag.tag);
      }).toList();
      
      if (matchingTags.isNotEmpty || cat.name.toLowerCase().contains(_searchQuery)) {
        filteredCategories.add(TagCategory(
          name: cat.name,
          description: cat.description,
          tags: matchingTags.isNotEmpty ? matchingTags : cat.tags,
        ));
      }
    }

    if (filteredCategories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('No se encontraron tags para tu búsqueda', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        return _CategoryExpansionTile(
          category: category,
          onTagTap: _copyTag,
          initiallyExpanded: true, // Expandir si hay búsqueda
        );
      },
    );
  }

  /// Determina si un tag es apto para mostrar al usuario final (oculta campos técnicos/IDs)
  bool _isUserFriendlyTag(String tag) {
    final lower = tag.toLowerCase();
    
    // Lista negra de sufijos y términos técnicos
    if (lower.endsWith('_id')) return false;
    if (lower.endsWith('id') && lower.length > 2) {
        // Excepción si es una palabra corta que termina en ID pero no es un ID técnico
        // Pero en este sistema, casi todo lo que termina en id es un foreign key
        return false;
    }
    if (lower == 'id') return false;
    if (lower.contains('token')) return false;
    if (lower.contains('password')) return false;
    if (lower.contains('created_at')) return false;
    if (lower.contains('updated_at')) return false;
    if (lower.contains('deleted_at')) return false;
    
    return true;
  }
}

class _CategoryExpansionTile extends StatelessWidget {
  final TagCategory category;
  final Function(String) onTagTap;
  final bool initiallyExpanded;

  const _CategoryExpansionTile({
    required this.category,
    required this.onTagTap,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: initiallyExpanded ? 2 : 1,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(
          _getCategoryIcon(category.name),
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          category.description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        children: category.tags.map((Tag tag) {
          final isCustom = tag.campoId != null;
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 4,
            ),
            leading: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isCustom 
                    ? Colors.orange.withOpacity(0.1)
                    : Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                isCustom ? Icons.auto_awesome : Icons.code,
                size: 16,
                color: isCustom ? Colors.orange[800] : Theme.of(context).primaryColor,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _normalizeTag(tag.tag),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isCustom ? Colors.orange[900] : Colors.black87,
                    ),
                  ),
                ),
                if (isCustom)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'CUSTOM',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              tag.description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            trailing: const Icon(Icons.add_circle_outline, size: 18, color: Colors.blue),
            onTap: () => onTagTap(tag.tag),
          );
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'servicio':
      case 'servicios':
        return Icons.build;
      case 'equipo':
      case 'equipos':
        return Icons.precision_manufacturing;
      case 'cliente':
        return Icons.business;
      case 'campos adicionales':
        return Icons.add_circle_outline;
      case 'especiales':
        return Icons.star;
      default:
        return Icons.label;
    }
  }
}

/// Normaliza cualquier representación del tag a la forma `{{nombre}}`
String _normalizeTag(String raw) {
  final t = raw.trim();
  final braceRegex = RegExp(r'^\{\{\s*(.+?)\s*\}\}$');
  final match = braceRegex.firstMatch(t);
  final core = match != null ? match.group(1)! : t;
  return '{{$core}}';
}
