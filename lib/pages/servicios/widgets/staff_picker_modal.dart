import 'package:flutter/material.dart';
import '../../staff/services/staff_services.dart';
import '../../staff/domain/staff_domain.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Modal para seleccionar personal (solo seleccié³n, sin guardar en API)
class StaffPickerModal extends StatefulWidget {
  final List<Staff> initialSelected;

  const StaffPickerModal({super.key, this.initialSelected = const []});

  @override
  State<StaffPickerModal> createState() => _StaffPickerModalState();
}

class _StaffPickerModalState extends State<StaffPickerModal> {
  List<Staff> _todosLosStaff = [];
  final Set<int> _seleccionIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Precargar seleccié³n inicial
    for (final s in widget.initialSelected) {
      final id = int.tryParse(s.id);
      if (id != null) _seleccionIds.add(id);
    }
    _cargarStaff();
  }

  Future<void> _cargarStaff() async {
    setState(() => _isLoading = true);
    try {
      final resp = await StaffApiService.getStaffList(isActive: true, limit: 100);
      if (resp.success && resp.data != null) {
        setState(() => _todosLosStaff = resp.data!);
      }
    } catch (e) {
      _mostrarError('Error cargando personal: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleStaff(Staff staff) {
    final id = int.tryParse(staff.id);
    if (id == null) return;
    setState(() {
      if (_seleccionIds.contains(id)) {
        _seleccionIds.remove(id);
      } else {
        _seleccionIds.add(id);
      }
    });
  }

  List<Staff> get _staffFiltrado {
    if (_searchQuery.isEmpty) return _todosLosStaff;
    final q = _searchQuery.toLowerCase();
    return _todosLosStaff.where((s) {
      return s.firstName.toLowerCase().contains(q) ||
          s.lastName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.staffCode.toLowerCase().contains(q);
    }).toList();
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
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
                  Icon(PhosphorIcons.users(), color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Seleccionar Personal',
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
                  hintText: 'Buscar personal...',
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            // Contador
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(children: [
                Icon(PhosphorIcons.checkCircle(), color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text('${_seleccionIds.length} seleccionado(s)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              ]),
            ),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _staffFiltrado.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIcons.magnifyingGlassPlus(), size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No hay personal disponible'
                                    : 'No se encontraron resultados',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _staffFiltrado.length,
                          itemBuilder: (context, index) {
                            final staff = _staffFiltrado[index];
                            final id = int.tryParse(staff.id);
                            final isSelected = id != null && _seleccionIds.contains(id);
                            return _buildStaffItem(staff, isSelected);
                          },
                        ),
            ),

            // Botones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Devolver la lista completa de Staff seleccionados (coincidencias por ID)
                      final seleccionados = _todosLosStaff
                          .where((s) => _seleccionIds.contains(int.tryParse(s.id) ?? -1))
                          .toList();
                      Navigator.pop<List<Staff>>(context, seleccionados);
                    },
                    icon: Icon(PhosphorIcons.floppyDisk()),
                    label: const Text('Guardar seleccié³n'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffItem(Staff staff, bool isSelected) {
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
        onChanged: (_) => _toggleStaff(staff),
        title: Text('${staff.firstName} ${staff.lastName}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(staff.email, style: TextStyle(color: Colors.grey.shade600)),
        secondary: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            staff.firstName[0] + staff.lastName[0],
            style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
