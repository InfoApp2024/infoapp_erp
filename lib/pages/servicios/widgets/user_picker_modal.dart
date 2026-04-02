import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../features/auth/data/admin_user_service.dart';

/// Modal para seleccionar usuarios (solo seleccié³n, sin guardar en API)
class UserPickerModal extends StatefulWidget {
  final List<AdminUser> initialSelected;

  const UserPickerModal({super.key, this.initialSelected = const []});

  @override
  State<UserPickerModal> createState() => _UserPickerModalState();
}

class _UserPickerModalState extends State<UserPickerModal> {
  List<AdminUser> _todosLosUsuarios = [];
  // Claves de seleccié³n compatibles: preferir codigoStaff, luego correo, luego ID
  final Set<String> _seleccionKeys = {};
  // Mantener el orden de seleccié³n para identificar al Responsable (primero)
  final List<String> _seleccionOrden = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Preseleccié³n flexible basada en los usuarios ya seleccionados
    for (final u in widget.initialSelected) {
      final key = _keyForUser(u);
      if (key.isNotEmpty) {
        _seleccionKeys.add(key);
        if (!_seleccionOrden.contains(key)) {
          _seleccionOrden.add(key);
        }
      }
    }
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final lista = await AdminUserService.listarUsuarios();
      // Filtrar usuarios inactivos: mostrar éºnicamente estado activo
      final activos = lista.where(_esUsuarioActivo).toList();
      // Deduplicar por clave lé³gica de usuario para evitar entradas repetidas
      final Map<String, AdminUser> porClave = {};
      for (final u in activos) {
        final k = _keyForUser(u);
        if (k.isNotEmpty) {
          porClave[k] = u; // mantener el éºltimo visto; evita duplicados visuales
        }
      }
      setState(() => _todosLosUsuarios = porClave.values.toList());
    } catch (e) {
      _mostrarError('Error cargando usuarios: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _esUsuarioActivo(AdminUser u) {
    final estado = (u.estado ?? '').toLowerCase().trim();
    if (estado.isEmpty) return true;
    return estado == 'activo' || estado == 'active' || estado == '1' || estado == 'true';
  }

  // Clave consistente para seleccié³n en creacié³n
  String _keyForUser(AdminUser u) {
    if (u.codigoStaff != null && u.codigoStaff!.isNotEmpty) return u.codigoStaff!;
    if (u.correo != null && u.correo!.isNotEmpty) return u.correo!;
    if (u.id > 0) return 'id:${u.id}';
    return u.usuario;
  }

  void _toggleUsuario(AdminUser u) {
    final key = _keyForUser(u);
    setState(() {
      if (_seleccionKeys.contains(key)) {
        _seleccionKeys.remove(key);
        _seleccionOrden.remove(key);
      } else {
        _seleccionKeys.add(key);
        _seleccionOrden.add(key);
      }
    });
  }

  List<AdminUser> get _usuariosFiltrados {
    if (_searchQuery.isEmpty) return _todosLosUsuarios;
    final q = _searchQuery.toLowerCase();
    return _todosLosUsuarios.where((u) {
      final nombre = (u.nombreCompleto ?? '').toLowerCase();
      return nombre.contains(q) || u.usuario.toLowerCase().contains(q) || (u.correo ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 680,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.userPlus(), color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Seleccionar Usuarios',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                  hintText: 'Buscar usuario...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(PhosphorIcons.checkCircle(), color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text('${_seleccionKeys.length} seleccionado(s)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              ]),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _usuariosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.magnifyingGlassPlus(), size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No hay usuarios disponibles' : 'No se encontraron resultados',
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
                        final isSelected = _seleccionKeys.contains(_keyForUser(u));
                        final isResponsible = _seleccionOrden.isNotEmpty &&
                            _seleccionOrden.first == _keyForUser(u);
                        return _buildUserItem(u, isSelected, isResponsible);
                      },
                    ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, <AdminUser>[]),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Ordenar la seleccié³n segéºn el orden elegido
                      final seleccion = _todosLosUsuarios
                          .where((u) => _seleccionKeys.contains(_keyForUser(u)))
                          .toList()
                        ..sort((a, b) => _seleccionOrden
                            .indexOf(_keyForUser(a))
                            .compareTo(_seleccionOrden.indexOf(_keyForUser(b))));
                      Navigator.pop(context, seleccion);
                    },
                    icon: Icon(PhosphorIcons.check()),
                    label: const Text('Seleccionar'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(AdminUser u, bool isSelected, bool isResponsible) {
    // Alinear con el modal de edicié³n: preferir `usuario` y caer a `nombreCompleto`.
    final nombreUsuario = u.usuario.trim().isNotEmpty
        ? u.usuario
        : (u.nombreCompleto ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (_) => _toggleUsuario(u),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(nombreUsuario, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (isResponsible) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).primaryColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.star(), size: 14, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 4),
                    Text('Responsable',
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
        // Sin subté­tulo para igualar el modal de edicié³n
        secondary: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            nombreUsuario.isNotEmpty ? nombreUsuario[0].toUpperCase() : '?',
            style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
