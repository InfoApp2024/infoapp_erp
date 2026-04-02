// lib/pages/inventory/models/inventory_form_data_models.dart
import 'inventory_supplier_model.dart';

// Clase para datos de formulario de categoría
class CategoryFormData {
  final String name;
  final String? description;
  final int? parentId;
  final bool isActive;
  final String? iconName;
  final String? color;

  const CategoryFormData({
    required this.name,
    this.description,
    this.parentId,
    this.isActive = true,
    this.iconName,
    this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'parent_id': parentId,
      'is_active': isActive,
      'icon_name': iconName,
      'color': color,
    };
  }

  factory CategoryFormData.fromJson(Map<String, dynamic> json) {
    return CategoryFormData(
      name: json['name'] as String,
      description: json['description'] as String?,
      parentId: json['parent_id'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      iconName: json['icon_name'] as String?,
      color: json['color'] as String?,
    );
  }

  CategoryFormData copyWith({
    String? name,
    String? description,
    int? parentId,
    bool? isActive,
    String? iconName,
    String? color,
  }) {
    return CategoryFormData(
      name: name ?? this.name,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
    );
  }

  List<String> validate() {
    List<String> errors = [];

    if (name.trim().isEmpty) {
      errors.add('El nombre de la categoría es obligatorio');
    }

    if (name.length > 100) {
      errors.add('El nombre no puede exceder 100 caracteres');
    }

    if (description != null && description!.length > 500) {
      errors.add('La descripción no puede exceder 500 caracteres');
    }

    return errors;
  }
}

// Clase para datos de formulario de proveedor
class SupplierFormData {
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

  const SupplierFormData({
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
  });

  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  factory SupplierFormData.fromJson(Map<String, dynamic> json) {
    return SupplierFormData(
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
    );
  }

  SupplierFormData copyWith({
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
  }) {
    return SupplierFormData(
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
    );
  }

  List<String> validate() {
    List<String> errors = [];

    if (name.trim().isEmpty) {
      errors.add('El nombre del proveedor es obligatorio');
    }

    if (name.length > 255) {
      errors.add('El nombre no puede exceder 255 caracteres');
    }

    if (email != null && email!.isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email!)) {
        errors.add('El email no tiene un formato válido');
      }
    }

    if (phone != null && phone!.isNotEmpty) {
      if (phone!.length < 7 || phone!.length > 20) {
        errors.add('El teléfono debe tener entre 7 y 20 caracteres');
      }
    }

    if (website != null && website!.isNotEmpty) {
      final uri = Uri.tryParse(website!);
      if (uri == null || uri.hasAbsolutePath != true) {
        errors.add('El sitio web no tiene un formato válido');
      }
    }

    return errors;
  }

  // Factory constructor desde InventorySupplier
  factory SupplierFormData.fromSupplier(InventorySupplier supplier) {
    return SupplierFormData(
      name: supplier.name,
      contactName: supplier.contactName,
      email: supplier.email,
      phone: supplier.phone,
      address: supplier.address,
      city: supplier.city,
      country: supplier.country,
      taxId: supplier.taxId,
      website: supplier.website,
      notes: supplier.notes,
      isActive: supplier.isActive,
    );
  }
}
