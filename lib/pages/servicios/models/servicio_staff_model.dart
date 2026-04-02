/// Modelo para representar la relación entre un servicio y el staff asignado
class ServicioStaffModel {
  final int? id; // ID de la tabla pivot servicio_staff
  final int servicioId;
  final int staffId;
  final String staffCode;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool isActive;
  final int? positionId;
  final String? positionTitle;
  final int? departmentId;
  final String? departmentName;
  final String? createdAt;
  final int? operacionId; // Link a la operación específica

  ServicioStaffModel({
    this.id,
    required this.servicioId,
    required this.staffId,
    required this.staffCode,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.email,
    this.phone,
    this.photoUrl,
    this.isActive = true,
    this.positionId,
    this.positionTitle,
    this.departmentId,
    this.departmentName,
    this.createdAt,
    this.operacionId,
  });

  /// Crear desde JSON (respuesta del backend)
  factory ServicioStaffModel.fromJson(Map<String, dynamic> json) {
    // Compatibilidad: aceptar estructuras provenientes de `usuarios`
    final int? parsedId =
        json['id'] is int
            ? json['id'] as int
            : int.tryParse(json['id']?.toString() ?? '');

    final int servicioId =
        (json['servicio_id'] is int
            ? json['servicio_id'] as int
            : int.tryParse(json['servicio_id']?.toString() ?? '')) ??
        (json['service_id'] is int
            ? json['service_id'] as int
            : int.tryParse(json['service_id']?.toString() ?? '')) ??
        0;

    final int staffId =
        (json['staff_id'] is int
            ? json['staff_id'] as int
            : int.tryParse(json['staff_id']?.toString() ?? '')) ??
        (json['usuario_id'] is int
            ? json['usuario_id'] as int
            : int.tryParse(json['usuario_id']?.toString() ?? '')) ??
        (json['user_id'] is int
            ? json['user_id'] as int
            : int.tryParse(json['user_id']?.toString() ?? '')) ??
        0;
    final String staffCode = json['staff_code'] as String? ?? '';

    // Nombres: aceptar `first_name/last_name` o `nombre/apellido`
    final String firstName =
        json['first_name'] as String? ?? json['nombre'] as String? ?? '';
    final String lastName =
        json['last_name'] as String? ?? json['apellido'] as String? ?? '';

    // full_name puede no venir; construir si faltan nombres
    String fullName = json['full_name'] as String? ?? '';
    if (fullName.isEmpty && (firstName.isNotEmpty || lastName.isNotEmpty)) {
      fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    }

    return ServicioStaffModel(
      id: parsedId,
      servicioId: servicioId,
      staffId: staffId,
      staffCode: staffCode,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      email: json['email'] as String? ?? json['correo'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      isActive:
          json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['activo'] == true ||
          json['activo'] == 1,
      positionId:
          json['position_id'] != null ? json['position_id'] as int : null,
      positionTitle: json['position_title'] as String?,
      departmentId:
          json['department_id'] != null ? json['department_id'] as int : null,
      departmentName: json['department_name'] as String?,
      createdAt: json['created_at'] as String?,
      operacionId:
          json['operacion_id'] is int
              ? json['operacion_id'] as int
              : int.tryParse(json['operacion_id']?.toString() ?? ''),
    );
  }

  /// Convertir a JSON (para enviar al backend)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'servicio_id': servicioId,
      'staff_id': staffId,
      'staff_code': staffCode,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'photo_url': photoUrl,
      'is_active': isActive,
      'position_id': positionId,
      'position_title': positionTitle,
      'department_name': departmentName,
      'created_at': createdAt,
      'operacion_id': operacionId,
    };
  }

  /// Crear copia con modificaciones
  ServicioStaffModel copyWith({
    int? id,
    int? servicioId,
    int? staffId,
    String? staffCode,
    String? firstName,
    String? lastName,
    String? fullName,
    String? email,
    String? phone,
    String? photoUrl,
    bool? isActive,
    int? positionId,
    String? positionTitle,
    int? departmentId,
    String? departmentName,
    String? createdAt,
    int? operacionId,
  }) {
    return ServicioStaffModel(
      id: id ?? this.id,
      servicioId: servicioId ?? this.servicioId,
      staffId: staffId ?? this.staffId,
      staffCode: staffCode ?? this.staffCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      positionId: positionId ?? this.positionId,
      positionTitle: positionTitle ?? this.positionTitle,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      createdAt: createdAt ?? this.createdAt,
      operacionId: operacionId ?? this.operacionId,
    );
  }

  @override
  String toString() {
    return 'ServicioStaffModel(id: $id, staffId: $staffId, fullName: $fullName, positionTitle: $positionTitle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServicioStaffModel &&
        other.staffId == staffId &&
        other.operacionId == operacionId;
  }

  @override
  int get hashCode => Object.hash(staffId, operacionId);
}
