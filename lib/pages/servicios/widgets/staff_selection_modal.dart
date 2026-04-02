import 'package:flutter/material.dart';
import '../../staff/services/staff_services.dart';
import '../../staff/domain/staff_domain.dart';
import '../models/servicio_staff_model.dart';
import '../services/servicios_api_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Modal para seleccionar y gestionar staff de un servicio
class StaffSelectionModal extends StatefulWidget {
  final int servicioId;
  final List<ServicioStaffModel> staffYaAsignado;
  final Function(List<ServicioStaffModel>)? onStaffActualizado;

  const StaffSelectionModal({
    super.key,
    required this.servicioId,
    required this.staffYaAsignado,
    this.onStaffActualizado,
  });

  @override
  State<StaffSelectionModal> createState() => _StaffSelectionModalState();
}

class _StaffSelectionModalState extends State<StaffSelectionModal> {
  List<Staff> _todosLosStaff = [];
  List<int> _staffSeleccionadosIds = []; // ? CAMBIO: int en lugar de String
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // ? CAMBIO: Convertir directamente a int
    _staffSeleccionadosIds =
        widget.staffYaAsignado.map((s) => s.staffId).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarStaff();
    });
  }

  Future<void> _cargarStaff() async {
    setState(() => _isLoading = true);

    try {
      final response = await StaffApiService.getStaffList(
        isActive: true,
        limit: 100,
      );

      if (response.success && response.data != null) {
        setState(() {
          _todosLosStaff = response.data!;
        });
      }
    } catch (e) {
      // Error cargando staff: $e
      _mostrarError('Error cargando personal: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _isSaving = true);

    try {
      // Filtrar IDs inválidos una vez más antes de enviar
      final idsValidos = _staffSeleccionadosIds.where((id) => id > 0).toList();

      // print('?? Enviando IDs de staff: $idsValidos');

      final response = await ServiciosApiService.actualizarStaffServicio(
        servicioId: widget.servicioId,
        staffIds: idsValidos,
      );

      if (response.isSuccess && response.data != null) {
        if (widget.onStaffActualizado != null) {
          widget.onStaffActualizado!(response.data!);
        }

        if (mounted) {
          _mostrarExito('Personal actualizado exitosamente');
          Navigator.pop(context, true);
        }
      } else {
        _mostrarError(response.error ?? 'Error al actualizar personal');
      }
    } catch (e) {
      _mostrarError('Error de conexié³n: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _toggleStaff(int staffId) {
    // ? CAMBIO: int en lugar de String
    setState(() {
      if (_staffSeleccionadosIds.contains(staffId)) {
        _staffSeleccionadosIds.remove(staffId);
      } else {
        _staffSeleccionadosIds.add(staffId);
      }
    });
  }

  List<Staff> get _staffFiltrado {
    if (_searchQuery.isEmpty) return _todosLosStaff;

    return _todosLosStaff.where((staff) {
      final query = _searchQuery.toLowerCase();
      return staff.firstName.toLowerCase().contains(query) ||
          staff.lastName.toLowerCase().contains(query) ||
          staff.email.toLowerCase().contains(query) ||
          staff.staffCode.toLowerCase().contains(query);
    }).toList();
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(PhosphorIcons.warningCircle(), color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarExito(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(PhosphorIcons.checkCircle(), color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gestionar Personal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Servicio #${widget.servicioId}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Contador de seleccionados
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(PhosphorIcons.checkCircle(), color: Theme.of(context).primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_staffSeleccionadosIds.length} seleccionado(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de staff
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _staffFiltrado.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIcons.magnifyingGlassPlus(),
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
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
                          // ? CAMBIO: Comparar con int
                          final isSelected = _staffSeleccionadosIds.contains(
                            int.parse(staff.id),
                          );

                          return _buildStaffItem(staff, isSelected);
                        },
                      ),
            ),

            // Botones de accié³n
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _guardarCambios,
                      icon:
                          _isSaving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Icon(PhosphorIcons.floppyDisk()),
                      label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
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
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged:
            (_) => _toggleStaff(
              int.tryParse(staff.id) ?? 0,
            ), // ? CAMBIO: Parseo seguro
        title: Text(
          '${staff.firstName} ${staff.lastName}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ver cargo', // Placeholder temporal
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        secondary: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            staff.firstName[0] + staff.lastName[0],
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
