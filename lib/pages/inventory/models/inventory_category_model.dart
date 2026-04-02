
class InventoryCategory {
  final int? id;
  final String name;
  final String? description;
  final int? parentId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int level;
  final String? iconName;
  final String? color;

  const InventoryCategory({
    this.id,
    required this.name,
    this.description,
    this.parentId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.level = 0,
    this.iconName,
    this.color,
  });

  // Factory constructor desde JSON
  factory InventoryCategory.fromJson(Map<String, dynamic> json) {
    return InventoryCategory(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      parentId: json['parent_id'] as int?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
      level: json['level'] as int? ?? 0,
      iconName: json['icon_name'] as String?,
      color: json['color'] as String?,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'parent_id': parentId,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'level': level,
      'icon_name': iconName,
      'color': color,
    };
  }

  // Método copyWith para crear copias modificadas
  InventoryCategory copyWith({
    int? id,
    String? name,
    String? description,
    int? parentId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? level,
    String? iconName,
    String? color,
  }) {
    return InventoryCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      level: level ?? this.level,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
    );
  }

  // Obtener la ruta completa de la categoría
  String getFullPath(List<InventoryCategory> allCategories) {
    if (parentId == null) return name;

    List<String> path = [name];
    InventoryCategory? current = this;

    while (current?.parentId != null) {
      InventoryCategory? parent =
          allCategories.where((cat) => cat.id == current!.parentId).firstOrNull;

      if (parent == null) break;

      path.insert(0, parent.name);
      current = parent;
    }

    return path.join(' > ');
  }

  // Verificar si es una categoría raíz
  bool get isRoot => parentId == null;

  // Verificar si es una categoría hoja (sin hijos)
  bool isLeaf(List<InventoryCategory> allCategories) {
    return !allCategories.any((cat) => cat.parentId == id);
  }

  // Obtener categorías hijas directas
  List<InventoryCategory> getChildren(List<InventoryCategory> allCategories) {
    return allCategories.where((cat) => cat.parentId == id).toList();
  }

  // Obtener todas las categorías descendientes (recursivo)
  List<InventoryCategory> getAllDescendants(
    List<InventoryCategory> allCategories,
  ) {
    List<InventoryCategory> descendants = [];
    List<InventoryCategory> children = getChildren(allCategories);

    for (InventoryCategory child in children) {
      descendants.add(child);
      descendants.addAll(child.getAllDescendants(allCategories));
    }

    return descendants;
  }

  // Obtener categoría padre
  InventoryCategory? getParent(List<InventoryCategory> allCategories) {
    if (parentId == null) return null;

    return allCategories.where((cat) => cat.id == parentId).firstOrNull;
  }

  // Obtener todos los ancestros (desde raíz hasta padre directo)
  List<InventoryCategory> getAncestors(List<InventoryCategory> allCategories) {
    List<InventoryCategory> ancestors = [];
    InventoryCategory? current = getParent(allCategories);

    while (current != null) {
      ancestors.insert(0, current);
      current = current.getParent(allCategories);
    }

    return ancestors;
  }

  // Verificar si puede tener una categoría como padre (evitar referencias circulares)
  bool canHaveParent(
    int? potentialParentId,
    List<InventoryCategory> allCategories,
  ) {
    if (potentialParentId == null || potentialParentId == id) return false;

    // Verificar que el potencial padre no sea descendiente de esta categoría
    List<InventoryCategory> descendants = getAllDescendants(allCategories);
    return !descendants.any((desc) => desc.id == potentialParentId);
  }

  // Calcular el nivel en la jerarquía
  int calculateLevel(List<InventoryCategory> allCategories) {
    int currentLevel = 0;
    InventoryCategory? current = getParent(allCategories);

    while (current != null) {
      currentLevel++;
      current = current.getParent(allCategories);
    }

    return currentLevel;
  }

  // Validar integridad de la categoría
  List<String> validate(List<InventoryCategory> allCategories) {
    List<String> errors = [];

    // Validar nombre
    if (name.trim().isEmpty) {
      errors.add('El nombre de la categoría es obligatorio');
    }

    // Validar longitud del nombre
    if (name.length > 100) {
      errors.add('El nombre no puede exceder 100 caracteres');
    }

    // Validar descripción si existe
    if (description != null && description!.length > 500) {
      errors.add('La descripción no puede exceder 500 caracteres');
    }

    // Validar padre si existe
    if (parentId != null) {
      InventoryCategory? parent = getParent(allCategories);
      if (parent == null) {
        errors.add('La categoría padre especificada no existe');
      } else if (!parent.isActive) {
        errors.add('La categoría padre debe estar activa');
      }
    }

    // Validar nivel máximo
    int currentLevel = calculateLevel(allCategories);
    if (currentLevel > 5) {
      errors.add('No se permite más de 5 niveles de jerarquía');
    }

    return errors;
  }

  // Método toString para debug
  @override
  String toString() {
    return 'InventoryCategory{id: $id, name: $name, parentId: $parentId, level: $level, isActive: $isActive}';
  }

  // Operadores de igualdad
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Extensión para trabajar con listas de categorías
extension InventoryCategoryListExtension on List<InventoryCategory> {
  // Obtener categorías raíz
  List<InventoryCategory> get rootCategories {
    return where((cat) => cat.isRoot).toList();
  }

  // Obtener categorías activas
  List<InventoryCategory> get activeCategories {
    return where((cat) => cat.isActive).toList();
  }

  // Buscar categoría por ID
  InventoryCategory? findById(int? id) {
    if (id == null) return null;
    return where((cat) => cat.id == id).firstOrNull;
  }

  // Buscar categorías por nombre (búsqueda parcial)
  List<InventoryCategory> searchByName(String query) {
    final lowerQuery = query.toLowerCase();
    return where(
      (cat) =>
          cat.name.toLowerCase().contains(lowerQuery) ||
          (cat.description?.toLowerCase().contains(lowerQuery) ?? false),
    ).toList();
  }

  // Construir árbol jerárquico
  List<CategoryTreeNode> buildTree() {
    List<CategoryTreeNode> roots = [];
    Map<int?, CategoryTreeNode> nodeMap = {};

    // Crear nodos
    for (InventoryCategory category in this) {
      nodeMap[category.id] = CategoryTreeNode(category: category);
    }

    // Construir relaciones padre-hijo
    for (InventoryCategory category in this) {
      CategoryTreeNode? node = nodeMap[category.id];
      if (node == null) continue;

      if (category.parentId != null && nodeMap.containsKey(category.parentId)) {
        CategoryTreeNode? parent = nodeMap[category.parentId];
        if (parent != null) {
          parent.children.add(node);
          node.parent = parent;
        }
      } else {
        roots.add(node);
      }
    }

    return roots;
  }

  // Obtener categorías por nivel
  List<InventoryCategory> getByLevel(int level) {
    return where((cat) => cat.level == level).toList();
  }

  // Validar integridad de toda la lista
  List<String> validateHierarchy() {
    List<String> errors = [];

    // Verificar referencias circulares
    for (InventoryCategory category in this) {
      if (_hasCircularReference(category)) {
        errors.add(
          'Referencia circular detectada en categoría: ${category.name}',
        );
      }
    }

    // Verificar huérfanos
    for (InventoryCategory category in this) {
      if (category.parentId != null &&
          !any((cat) => cat.id == category.parentId)) {
        errors.add('Categoría huérfana encontrada: ${category.name}');
      }
    }

    return errors;
  }

  bool _hasCircularReference(InventoryCategory category) {
    Set<int?> visited = {};
    InventoryCategory? current = category;

    while (current != null) {
      if (visited.contains(current.id)) {
        return true; // Referencia circular detectada
      }

      visited.add(current.id);
      current = current.getParent(this);
    }

    return false;
  }
}

// Clase para representar nodos del árbol de categorías
class CategoryTreeNode {
  final InventoryCategory category;
  CategoryTreeNode? parent;
  final List<CategoryTreeNode> children = [];

  CategoryTreeNode({required this.category});

  // Verificar si es nodo raíz
  bool get isRoot => parent == null;

  // Verificar si es nodo hoja
  bool get isLeaf => children.isEmpty;

  // Obtener profundidad del nodo
  int get depth {
    int level = 0;
    CategoryTreeNode? current = parent;

    while (current != null) {
      level++;
      current = current.parent;
    }

    return level;
  }

  // Obtener ruta desde la raíz
  List<InventoryCategory> get pathFromRoot {
    List<InventoryCategory> path = [];
    CategoryTreeNode? current = this;

    while (current != null) {
      path.insert(0, current.category);
      current = current.parent;
    }

    return path;
  }

  // Obtener todos los descendientes
  List<CategoryTreeNode> get allDescendants {
    List<CategoryTreeNode> descendants = [];

    for (CategoryTreeNode child in children) {
      descendants.add(child);
      descendants.addAll(child.allDescendants);
    }

    return descendants;
  }
}
