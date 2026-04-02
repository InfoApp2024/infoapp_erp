import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/features/auth/data/admin_user_service.dart';
import 'package:infoapp/pages/staff/services/staff_services.dart';

class SeleccionarStaffDialog extends StatefulWidget {
  const SeleccionarStaffDialog({super.key});

  @override
  State<SeleccionarStaffDialog> createState() => _SeleccionarStaffDialogState();
}

class _SeleccionarStaffDialogState extends State<SeleccionarStaffDialog> {
  List<AdminUser> _usuarios = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _isLoading = true);
    try {
      // Cargar ambos en paralelo
      final resultados = await Future.wait([
        AdminUserService.listarUsuarios(),
        StaffApiService.getStaffList(isActive: true, limit: 1000),
      ]);

      final listaUsuarios = resultados[0] as List<AdminUser>;
      final apiResponseStaff = resultados[1] as ApiResponse<List<dynamic>>;

      final List<AdminUser> combinados = [];

      // 1. Agregar Usuarios (Administradores)
      combinados.addAll(listaUsuarios.where(_esUsuarioActivo));

      // 2. Agregar Staff (Técnicos) convertidos a AdminUser con offset
      if (apiResponseStaff.success && apiResponseStaff.data != null) {
        for (var s in apiResponseStaff.data!) {
          final staff = s;
          final idInt = int.tryParse(staff.id) ?? 0;
          if (idInt == 0) continue;

          combinados.add(
            AdminUser(
              id: idInt + 1000000, // Offset para distinguir en backend
              usuario: staff.firstName,
              nombreCompleto: "${staff.firstName} ${staff.lastName}",
              correo: staff.email,
              rol: 'técnico',
              estado: 'activo',
              codigoStaff: staff.staffCode,
            ),
          );
        }
      }

      setState(() => _usuarios = combinados);
    } catch (e) {
      _mostrarSnack('Error cargando personal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _esUsuarioActivo(AdminUser u) {
    final estado = (u.estado ?? '').toLowerCase().trim();
    if (estado.isEmpty) return true;
    return estado == 'activo' ||
        estado == 'active' ||
        estado == '1' ||
        estado == 'true';
  }

  List<AdminUser> get _usuariosFiltrados {
    if (_searchQuery.isEmpty) return _usuarios;
    final q = _searchQuery.toLowerCase();
    return _usuarios.where((u) {
      final nombre = (u.nombreCompleto ?? '').toLowerCase();
      final usuario = u.usuario.toLowerCase();
      final correo = (u.correo ?? '').toLowerCase();
      return nombre.contains(q) || usuario.contains(q) || correo.contains(q);
    }).toList();
  }

  void _mostrarSnack(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? PhosphorIcons.warningCircle()
                  : PhosphorIcons.checkCircle(),
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.user(), color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Seleccionar Usuario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.x(), color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Buscador
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar usuario...',
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Lista
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _usuariosFiltrados.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIcons.magnifyingGlass(),
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No hay usuarios disponibles'
                                  : 'No se encontraron resultados',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _usuariosFiltrados.length,
                        itemBuilder: (context, index) {
                          final u = _usuariosFiltrados[index];
                          // Formato alineado con modal de servicios: preferir `usuario` y caer a `nombreCompleto`.
                          final nombreUsuario =
                              u.usuario.trim().isNotEmpty
                                  ? u.usuario
                                  : (u.nombreCompleto ?? '');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                child: Text(
                                  (nombreUsuario.isNotEmpty
                                          ? nombreUsuario[0]
                                          : (u.id > 1000000 ? 'T' : 'U'))
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(nombreUsuario),
                              subtitle: Text(
                                u.id > 1000000
                                    ? 'Personal Técnico - ${u.correo ?? ""}'
                                    : 'Administrador - ${u.correo ?? ""}',
                              ),
                              trailing: Icon(PhosphorIcons.check()),
                              onTap: () => Navigator.pop(context, u),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
