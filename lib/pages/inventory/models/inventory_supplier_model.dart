
class InventorySupplier {
  final String id;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? country;
  final String? taxId;
  final String? website;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventorySupplier({
    required this.id,
    required this.name,
    this.contactName,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.country,
    this.taxId,
    this.website,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor desde JSON
  factory InventorySupplier.fromJson(Map<String, dynamic> json) {
    return InventorySupplier(
      id: json['id'].toString(),
      name: json['name'] as String,
      contactName: json['contact_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      taxId: json['tax_id'] as String?,
      website: json['website'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact_name': contactName,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'country': country,
      'tax_id': taxId,
      'website': website,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Método copyWith para crear copias modificadas
  InventorySupplier copyWith({
    String? id,
    String? name,
    String? contactName,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? country,
    String? taxId,
    String? website,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventorySupplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      taxId: taxId ?? this.taxId,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Obtener dirección completa
  String get fullAddress {
    List<String> addressParts = [];

    if (address != null && address!.isNotEmpty) {
      addressParts.add(address!);
    }
    if (city != null && city!.isNotEmpty) {
      addressParts.add(city!);
    }
    if (country != null && country!.isNotEmpty) {
      addressParts.add(country!);
    }

    return addressParts.join(', ');
  }

  // Obtener información de contacto principal
  String? get primaryContact {
    if (contactName != null && contactName!.isNotEmpty) {
      return contactName;
    }
    if (email != null && email!.isNotEmpty) {
      return email;
    }
    if (phone != null && phone!.isNotEmpty) {
      return phone;
    }
    return null;
  }

  // Validar email si existe
  bool get hasValidEmail {
    if (email == null || email!.isEmpty) {
      return true; // Email opcional es válido
    }
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email!);
  }

  // Validar datos básicos del proveedor
  List<String> validate() {
    List<String> errors = [];

    // Validar nombre
    if (name.trim().isEmpty) {
      errors.add('El nombre del proveedor es obligatorio');
    }

    // Validar longitud del nombre
    if (name.length > 255) {
      errors.add('El nombre no puede exceder 255 caracteres');
    }

    // Validar email si existe
    if (!hasValidEmail) {
      errors.add('El email no tiene un formato válido');
    }

    // Validar teléfono si existe
    if (phone != null && phone!.isNotEmpty) {
      if (phone!.length < 7 || phone!.length > 20) {
        errors.add('El teléfono debe tener entre 7 y 20 caracteres');
      }
    }

    // Validar website si existe
    if (website != null && website!.isNotEmpty) {
      final uri = Uri.tryParse(website!);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        errors.add('El sitio web no tiene un formato válido');
      }
    }

    return errors;
  }

  // Obtener texto buscable para filtros
  String get searchableText {
    return [
      name,
      contactName ?? '',
      email ?? '',
      phone ?? '',
      city ?? '',
      country ?? '',
      taxId ?? '',
    ].join(' ').toLowerCase();
  }

  // Verificar si tiene información de contacto completa
  bool get hasCompleteContactInfo {
    return (contactName != null && contactName!.isNotEmpty) &&
        (email != null && email!.isNotEmpty) &&
        (phone != null && phone!.isNotEmpty);
  }

  // Verificar si tiene dirección completa
  bool get hasCompleteAddress {
    return (address != null && address!.isNotEmpty) &&
        (city != null && city!.isNotEmpty) &&
        (country != null && country!.isNotEmpty);
  }

  // Obtener score de completitud (0-100)
  int get completenessScore {
    int score = 0;
    int totalFields = 9; // Campos opcionales importantes

    if (contactName != null && contactName!.isNotEmpty) score++;
    if (email != null && email!.isNotEmpty) score++;
    if (phone != null && phone!.isNotEmpty) score++;
    if (address != null && address!.isNotEmpty) score++;
    if (city != null && city!.isNotEmpty) score++;
    if (country != null && country!.isNotEmpty) score++;
    if (taxId != null && taxId!.isNotEmpty) score++;
    if (website != null && website!.isNotEmpty) score++;
    if (notes != null && notes!.isNotEmpty) score++;

    return ((score / totalFields) * 100).round();
  }

  // Método toString para debug
  @override
  String toString() {
    return 'InventorySupplier{id: $id, name: $name, email: $email, isActive: $isActive}';
  }

  // Operadores de igualdad
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventorySupplier &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Extensión para trabajar con listas de proveedores
extension InventorySupplierListExtension on List<InventorySupplier> {
  // Obtener proveedores activos
  List<InventorySupplier> get activeSuppliers {
    return where((supplier) => supplier.isActive).toList();
  }

  // Buscar proveedor por ID
  InventorySupplier? findById(String id) {
    try {
      return firstWhere((supplier) => supplier.id == id);
    } catch (e) {
      return null;
    }
  }

  // Buscar proveedores por nombre (búsqueda parcial)
  List<InventorySupplier> searchByName(String query) {
    final lowerQuery = query.toLowerCase();
    return where(
      (supplier) => supplier.searchableText.contains(lowerQuery),
    ).toList();
  }

  // Obtener proveedores por país
  List<InventorySupplier> getByCountry(String country) {
    return where(
      (supplier) => supplier.country?.toLowerCase() == country.toLowerCase(),
    ).toList();
  }

  // Obtener proveedores con información completa
  List<InventorySupplier> get completeSuppliers {
    return where(
      (supplier) =>
          supplier.hasCompleteContactInfo && supplier.hasCompleteAddress,
    ).toList();
  }

  // Obtener proveedores con email
  List<InventorySupplier> get suppliersWithEmail {
    return where(
      (supplier) => supplier.email != null && supplier.email!.isNotEmpty,
    ).toList();
  }

  // Ordenar por nombre
  List<InventorySupplier> sortedByName({bool ascending = true}) {
    final sorted = List<InventorySupplier>.from(this);
    sorted.sort(
      (a, b) => ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name),
    );
    return sorted;
  }

  // Ordenar por fecha de creación
  List<InventorySupplier> sortedByDate({bool ascending = true}) {
    final sorted = List<InventorySupplier>.from(this);
    sorted.sort(
      (a, b) =>
          ascending
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt),
    );
    return sorted;
  }

  // Obtener estadísticas de la lista
  Map<String, dynamic> get statistics {
    final activeCount = activeSuppliers.length;
    final withEmailCount = suppliersWithEmail.length;
    final completeCount = completeSuppliers.length;
    final countries = map((s) => s.country).where((c) => c != null).toSet();

    return {
      'total': length,
      'active': activeCount,
      'inactive': length - activeCount,
      'with_email': withEmailCount,
      'complete_info': completeCount,
      'countries_count': countries.length,
      'countries': countries.toList(),
    };
  }
}
