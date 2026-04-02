import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/utils/connectivity_service.dart';

class AdminUser {
  final int id;
  final String usuario;
  final String? nombreCompleto;
  final String? correo;
  final String rol;
  final String estado;
  final String? telefono;
  final String? tipoIdentificacion;
  final String? numeroIdentificacion;
  final String? codigoStaff;
  final String? urlFoto;
  final String? fechaNacimiento;
  final String? fechaContratacion;
  final int? idPosicion;
  final int? idDepartamento;
  final int? idEspecialidad;
  final double? salario;
  final String? direccion;
  final String? contactoEmergenciaNombre;
  final String? contactoEmergenciaTelefono;
  final int? funcionarioId;
  final bool esAuditor;
  final bool canEditClosedOps;

  AdminUser({
    required this.id,
    required this.usuario,
    this.nombreCompleto,
    this.correo,
    required this.rol,
    required this.estado,
    this.telefono,
    this.tipoIdentificacion,
    this.numeroIdentificacion,
    this.codigoStaff,
    this.urlFoto,
    this.fechaNacimiento,
    this.fechaContratacion,
    this.idPosicion,
    this.idDepartamento,
    this.idEspecialidad,
    this.salario,
    this.direccion,
    this.contactoEmergenciaNombre,
    this.contactoEmergenciaTelefono,
    this.funcionarioId,
    this.esAuditor = false,
    this.canEditClosedOps = false,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id:
          json['id'] is String
              ? int.tryParse(json['id']) ?? 0
              : (json['id'] ?? 0),
      usuario: json['usuario'] ?? json['username'] ?? json['NOMBRE_USER'] ?? '',
      nombreCompleto:
          json['nombre_completo'] ??
          json['NOMBRE_USER'] ??
          json['nombreCompleto'] ??
          json['NOMBRE_CLIENTE'],
      correo: json['correo'] ?? json['CORREO'] ?? json['email'],
      rol: json['rol'] ?? json['TIPO_ROL'] ?? 'usuario',
      estado: json['estado'] ?? json['ESTADO_USER'] ?? 'activo',
      telefono: json['TELEFONO'] ?? json['telefono'],
      tipoIdentificacion:
          json['TIPO_IDENTIFICACION'] ?? json['tipo_identificacion'],
      numeroIdentificacion:
          json['NUMERO_IDENTIFICACION'] ?? json['numero_identificacion'],
      codigoStaff: json['CODIGO_STAFF'] ?? json['codigo_staff'],
      urlFoto: json['URL_FOTO'] ?? json['url_foto'] ?? json['uri_foto'],
      fechaNacimiento: json['FECHA_NACIMIENTO'] ?? json['fecha_nacimiento'],
      fechaContratacion:
          json['FECHA_CONTRATACION'] ?? json['fecha_contratacion'],
      idPosicion:
          (json['ID_POSICION'] ?? json['id_posicion']) != null
              ? int.tryParse(
                (json['ID_POSICION'] ?? json['id_posicion']).toString(),
              )
              : null,
      idDepartamento:
          (json['ID_DEPARTAMENTO'] ?? json['id_departamento']) != null
              ? int.tryParse(
                (json['ID_DEPARTAMENTO'] ?? json['id_departamento']).toString(),
              )
              : null,
      idEspecialidad:
          (json['ID_ESPECIALIDAD'] ?? json['id_especialidad']) != null
              ? int.tryParse(
                (json['ID_ESPECIALIDAD'] ?? json['id_especialidad']).toString(),
              )
              : null,
      salario:
          (json['SALARIO'] ?? json['salario']) != null
              ? double.tryParse((json['SALARIO'] ?? json['salario']).toString())
              : null,
      direccion: json['DIRECCION'] ?? json['direccion'],
      contactoEmergenciaNombre:
          json['CONTACTO_EMERGENCIA_NOMBRE'] ??
          json['contacto_emergencia_nombre'],
      contactoEmergenciaTelefono:
          json['CONTACTO_EMERGENCIA_TELEFONO'] ??
          json['contacto_emergencia_telefono'],
      funcionarioId:
          (json['funcionario_id'] ?? json['id_funcionario']) != null
              ? int.tryParse(
                (json['funcionario_id'] ?? json['id_funcionario']).toString(),
              )
              : null,
      esAuditor: json['es_auditor'] == true ||
          json['es_auditor'] == 1 ||
          json['es_auditor'] == '1',
      canEditClosedOps: json['can_edit_closed_ops'] == true ||
          json['can_edit_closed_ops'] == 1 ||
          json['can_edit_closed_ops'] == '1',
    );
  }
}

class AdminUserService {
  // Base URL dinámico según servidor seleccionado
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('login');

  // Headers con autenticación JWT - SIEMPRE JSON
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = token;
    }
    return headers;
  }

  // LISTAR
  static Future<List<AdminUser>> listarUsuarios({
    String? query,
    bool includeClients = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'cache_admin_users';
    final isOnline = await ConnectivityService.instance.checkNow();

    // Fallback offline: usar caché y filtrar si hay query
    Future<List<AdminUser>> loadFromCache() async {
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return [];
      try {
        final decoded = jsonDecode(raw);
        List<dynamic> items;
        if (decoded is Map && decoded['items'] is List) {
          items = decoded['items'] as List<dynamic>;
        } else if (decoded is List) {
          items = decoded;
        } else {
          return [];
        }
        var list =
            items
                .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
                .toList();
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          list =
              list.where((u) {
                final nombre = (u.nombreCompleto ?? u.usuario).toLowerCase();
                final correo = (u.correo ?? '').toLowerCase();
                return nombre.contains(q) || correo.contains(q);
              }).toList();
        }
        return list;
      } catch (_) {
        return [];
      }
    }

    if (!isOnline) {
      final cached = await loadFromCache();
      if (cached.isNotEmpty) return cached;
    }

    try {
      final allUsers = <AdminUser>[];
      int page = 1;
      const limit = 100; // Máximo permitido por backend
      bool hasNext = true;

      while (hasNext) {
        final uri = Uri.parse(
          '$_baseUrl/listar_usuarios.php?page=$page&limit=$limit'
          '${includeClients ? '&include_clients=1' : ''}'
          '${(query != null && query.trim().isNotEmpty) ? '&search=${Uri.encodeQueryComponent(query.trim())}' : ''}',
        );

        final response = await http
            .get(uri, headers: await _getAuthHeaders())
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          // Si falla la primera página y tenemos caché, usarla
          if (page == 1) {
            final cached = await loadFromCache();
            if (cached.isNotEmpty) return cached;
          }
          throw Exception('Error al cargar usuarios (${response.statusCode})');
        }

        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == false) {
          final msg = (data['message'] ?? '').toString().toLowerCase();
          if (msg.contains('no autorizado') || response.statusCode == 401) {
            await AuthService.clearAuthData();
            throw Exception('No autorizado');
          }
          // Si falla la primera página, fallback a caché
          if (page == 1) {
            final cached = await loadFromCache();
            if (cached.isNotEmpty) return cached;
          }
          throw Exception(data['message'] ?? 'Error al cargar usuarios');
        }

        List<dynamic> pageUsersData = [];
        if (data is Map) {
          final success =
              data['success'] == null ? true : data['success'] == true;
          if (success) {
            if (data['data'] is List) {
              pageUsersData = data['data'] as List<dynamic>;
            } else if (data['users'] is List) {
              pageUsersData = data['users'] as List<dynamic>;
            } else if (data['usuarios'] is List) {
              pageUsersData = data['usuarios'] as List<dynamic>;
            }
          }

          // Verificar paginación del backend
          if (data['pagination'] is Map) {
            hasNext = data['pagination']['has_next'] == true;
          } else {
            // Si no hay info de paginación, asumir que si recibimos menos del límite, es el final
            hasNext = pageUsersData.length >= limit;
          }
        } else if (data is List) {
          // Formato antiguo lista directa
          pageUsersData = data;
          hasNext = false; // Asumir que devolvió todo si es lista directa
        }

        final pageUsers =
            pageUsersData
                .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
                .toList();

        allUsers.addAll(pageUsers);

        // Seguridad para loop infinito
        if (pageUsers.isEmpty) hasNext = false;
        page++;
      }

      // Guardar en caché (solo si no filtramos por query, para tener la lista completa)
      if (query == null || query.trim().isEmpty) {
        try {
          final itemsJson =
              allUsers.map((u) {
                // Reconstruir JSON aproximado ya que AdminUser no tiene toJson completo a veces
                // Pero aquí venimos de jsonDecode, así que mejor no serializar objetos,
                // sino guardar lo que ya procesamos si pudiéramos.
                // Como ya convertimos a objetos, serializamos manualmente lo básico o implementamos toJson.
                // AdminUser parece no tener toJson en el snippet que vi.
                // Mejor estrategia: Guardar el resultado acumulado.
                return {
                  'id': u.id,
                  'usuario': u.usuario,
                  'nombre_completo': u.nombreCompleto,
                  'correo': u.correo,
                  'rol': u.rol,
                  'estado': u.estado,
                  // Agregar otros campos necesarios...
                  'telefono': u.telefono,
                  'codigo_staff': u.codigoStaff,
                  'url_foto': u.urlFoto,
                  'funcionario_id': u.funcionarioId,
                  'es_auditor': u.esAuditor,
                  'can_edit_closed_ops': u.canEditClosedOps,
                };
              }).toList();

          final payload = jsonEncode({
            'items': itemsJson,
            'ts': DateTime.now().millisecondsSinceEpoch,
          });
          await prefs.setString(cacheKey, payload);
        } catch (_) {}
      }

      return allUsers;
    } catch (e) {
      // Fallback a caché global
      final cached = await loadFromCache();
      if (cached.isNotEmpty) return cached;
      throw Exception('No fue posible cargar usuarios: $e');
    }
  }

  // Invalidar caché local de usuarios para evitar datos obsoletos tras actualizaciones
  static Future<void> invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_admin_users');
    } catch (_) {}
  }

  // CREAR
  static Future<AdminUser> crearUsuario({
    required String usuario,
    required String password,
    String? nombreCompleto,
    String? correo,
    String rol = 'colaborador',
    String estado = 'activo',
    String? telefono,
    String? tipoIdentificacion,
    String? numeroIdentificacion,
    String? codigoStaff,
    String? urlFoto,
    String? fechaNacimiento,
    String? contactoEmergenciaNombre,
    String? contactoEmergenciaTelefono,
    String? direccion,
    String? fechaContratacion,
    int? idPosicion,
    int? idDepartamento,
    int? idEspecialidad,
    double? salario,
    int? funcionarioId,
    bool? esAuditor,
    bool? canEditClosedOps,
  }) async {
    final uri = Uri.parse('$_baseUrl/crear_usuarios.php');

    final payload = {
      'NOMBRE_USER': nombreCompleto ?? usuario,
      // Algunos endpoints requieren NOMBRE_CLIENTE como nombre completo del usuario
      'NOMBRE_CLIENTE': nombreCompleto ?? usuario,
      'CONTRASEÑA': password,
      'NIT': numeroIdentificacion ?? '0',
      'CORREO': correo ?? '',
      'TIPO_ROL': rol,
      'ESTADO_USER': estado,
      if (telefono != null) 'TELEFONO': telefono,
      if (tipoIdentificacion != null) 'TIPO_IDENTIFICACION': tipoIdentificacion,
      if (numeroIdentificacion != null)
        'NUMERO_IDENTIFICACION': numeroIdentificacion,
      if (codigoStaff != null) 'CODIGO_STAFF': codigoStaff,
      if (urlFoto != null) 'URL_FOTO': urlFoto,
      // Algunos endpoints usan 'uri_foto' en lugar de 'URL_FOTO'
      if (urlFoto != null) 'uri_foto': urlFoto,
      if (fechaNacimiento != null) 'FECHA_NACIMIENTO': fechaNacimiento,
      if (contactoEmergenciaNombre != null)
        'CONTACTO_EMERGENCIA_NOMBRE': contactoEmergenciaNombre,
      if (contactoEmergenciaTelefono != null)
        'CONTACTO_EMERGENCIA_TELEFONO': contactoEmergenciaTelefono,
      if (direccion != null) 'DIRECCION': direccion,
      if (fechaContratacion != null) 'FECHA_CONTRATACION': fechaContratacion,
      if (idPosicion != null) 'ID_POSICION': idPosicion,
      if (idDepartamento != null) 'ID_DEPARTAMENTO': idDepartamento,
      if (idEspecialidad != null) 'ID_ESPECIALIDAD': idEspecialidad,
      if (salario != null) 'SALARIO': salario,
      if (funcionarioId != null) 'funcionario_id': funcionarioId,
      if (esAuditor != null) 'es_auditor': esAuditor,
      if (canEditClosedOps != null) 'can_edit_closed_ops': canEditClosedOps,
    };

    final response = await http
        .post(uri, headers: await _getAuthHeaders(), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Error al crear usuario (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    if (data is Map && data['success'] == false) {
      final msg = (data['message'] ?? '').toString().toLowerCase();
      if (msg.contains('no autorizado') || response.statusCode == 401) {
        await AuthService.clearAuthData();
        throw Exception('No autorizado');
      }
      throw Exception(data['message'] ?? 'No fue posible crear el usuario');
    }

    if (data is Map && (data['success'] == true || data['data'] != null)) {
      final userData = data['data'] as Map<String, dynamic>? ?? {};
      return AdminUser.fromJson({
        ...userData,
        'usuario': userData['usuario'] ?? usuario,
        'nombre_completo': userData['nombre_completo'] ?? nombreCompleto,
        'correo': userData['correo'] ?? correo,
        'rol': userData['rol'] ?? rol,
        'estado': userData['estado'] ?? estado,
        'funcionario_id': userData['funcionario_id'] ?? funcionarioId,
        'es_auditor': userData['es_auditor'] ?? esAuditor ?? false,
        'can_edit_closed_ops': userData['can_edit_closed_ops'] ?? canEditClosedOps ?? false,
      });
    }

    throw Exception(
      data is Map && data['message'] != null
          ? data['message']
          : 'No fue posible crear el usuario',
    );
  }

  // ACTUALIZAR - ✅ CORRECTO: Usar JSON, no form-urlencoded
  static Future<bool> actualizarUsuario({
    required int id,
    String? usuario,
    String? password,
    String? nombreCompleto,
    String? correo,
    String? rol,
    String? estado,
    String? telefono,
    String? tipoIdentificacion,
    String? numeroIdentificacion,
    String? codigoStaff,
    String? urlFoto,
    String? fechaNacimiento,
    String? contactoEmergenciaNombre,
    String? contactoEmergenciaTelefono,
    String? direccion,
    String? fechaContratacion,
    int? idPosicion,
    int? idDepartamento,
    int? idEspecialidad,
    double? salario,
    int? funcionarioId,
    String? nit,
    bool? esAuditor,
    bool? canEditClosedOps,
  }) async {
    final uri = Uri.parse('$_baseUrl/actualizar_usuarios.php');

    final payload = {
      'id': id,
      if (usuario != null) 'NOMBRE_USER': usuario,
      if (password != null) 'CONTRASEÑA': password,
      if (nombreCompleto != null) 'NOMBRE_CLIENTE': nombreCompleto,
      if (correo != null) 'CORREO': correo,
      if (rol != null) 'TIPO_ROL': rol,
      if (estado != null) 'ESTADO_USER': estado,
      if (telefono != null) 'TELEFONO': telefono,
      if (tipoIdentificacion != null) 'TIPO_IDENTIFICACION': tipoIdentificacion,
      if (nit != null) 'NIT': nit,
      if (numeroIdentificacion != null)
        'NUMERO_IDENTIFICACION': numeroIdentificacion,
      if (codigoStaff != null) 'CODIGO_STAFF': codigoStaff,
      if (urlFoto != null) 'URL_FOTO': urlFoto,
      // Compatibilidad con respuestas que usan 'uri_foto'
      if (urlFoto != null) 'uri_foto': urlFoto,
      if (fechaNacimiento != null) 'FECHA_NACIMIENTO': fechaNacimiento,
      if (contactoEmergenciaNombre != null)
        'CONTACTO_EMERGENCIA_NOMBRE': contactoEmergenciaNombre,
      if (contactoEmergenciaTelefono != null)
        'CONTACTO_EMERGENCIA_TELEFONO': contactoEmergenciaTelefono,
      if (direccion != null) 'DIRECCION': direccion,
      if (fechaContratacion != null) 'FECHA_CONTRATACION': fechaContratacion,
      if (idPosicion != null) 'ID_POSICION': idPosicion,
      if (idDepartamento != null) 'ID_DEPARTAMENTO': idDepartamento,
      if (idEspecialidad != null) 'ID_ESPECIALIDAD': idEspecialidad,
      if (salario != null) 'SALARIO': salario,
      if (funcionarioId != null) 'funcionario_id': funcionarioId,
      if (esAuditor != null) 'es_auditor': esAuditor,
      if (canEditClosedOps != null) 'can_edit_closed_ops': canEditClosedOps,
    };

    final response = await http
        .post(uri, headers: await _getAuthHeaders(), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body);
      final errorMsg = errorBody['message'] ?? 'Error al actualizar usuario';
      throw Exception('$errorMsg (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    if (data is Map && data['success'] == false) {
      final msg = (data['message'] ?? '').toString().toLowerCase();
      if (msg.contains('no autorizado') || response.statusCode == 401) {
        await AuthService.clearAuthData();
        return false;
      }
      throw Exception(data['message'] ?? 'Error al actualizar usuario');
    }

    return data is Map && data['success'] == true;
  }

  // ELIMINAR
  static Future<bool> eliminarUsuario(int id, {bool permanente = false}) async {
    final uri = Uri.parse('$_baseUrl/eliminar_usuarios.php');

    final payload = {
      'id': id,
      if (permanente) 'tipo': 'eliminar' else 'tipo': 'desactivar',
      if (permanente) 'confirmar': true,
    };

    final response = await http
        .post(uri, headers: await _getAuthHeaders(), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar usuario (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    if (data is Map && data['success'] == false) {
      final msg = (data['message'] ?? '').toString().toLowerCase();
      if (msg.contains('no autorizado') || response.statusCode == 401) {
        await AuthService.clearAuthData();
        return false;
      }
      throw Exception(data['message'] ?? 'Error al eliminar usuario');
    }

    // Invalidar caché tras eliminación exitosa
    await invalidateCache();

    return data is Map && data['success'] == true;
  }

  // RESET DE CONTRASEÑA (ADMIN)
  static Future<bool> resetPasswordAdmin({
    required int userId,
    required String nuevaPassword,
  }) async {
    return actualizarUsuario(id: userId, password: nuevaPassword);
  }
}
