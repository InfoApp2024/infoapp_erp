// =====================================================
// UI COMPONENTS - Reusable Widgets - PARTE 1 DE 4
// =====================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:infoapp/pages/staff/services/staff_photo_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../domain/staff_domain.dart';
import '../presentation/staff_presentation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Avatar de usuario con manejo de errores y forma constante
class StaffAvatar extends StatefulWidget {
  final String? photoUrl;
  final String initials;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const StaffAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.radius = 30,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<StaffAvatar> createState() => _StaffAvatarState();
}

class _StaffAvatarState extends State<StaffAvatar> {
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await AuthService.getBearerToken();
    if (mounted) {
      setState(() => _authToken = token);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Normalizar URL si es relativa
    String? finalUrl = widget.photoUrl;
    if (finalUrl != null &&
        finalUrl.isNotEmpty &&
        !finalUrl.startsWith('http')) {
      final baseUrl = ServerConfig.instance.baseUrlFor('login');
      finalUrl = '$baseUrl/ver_imagen.php?ruta=$finalUrl';
    }

    if (finalUrl != null) {
      // debugPrint('[StaffAvatar] Building with URL: $finalUrl');
      // debugPrint('[StaffAvatar] Has Token: ${_authToken != null}');
    }

    final size = widget.radius * 2;
    final placeholder = Container(
      color: widget.backgroundColor ?? Theme.of(context).primaryColor,
      alignment: Alignment.center,
      child: Text(
        widget.initials,
        style: TextStyle(
          fontSize: widget.radius * 0.6,
          fontWeight: FontWeight.bold,
          color: widget.textColor ?? Colors.white,
        ),
      ),
    );

    Widget content;
    if (finalUrl != null && finalUrl.isNotEmpty) {
      content = Image.network(
        finalUrl,
        headers: _authToken != null ? {'Authorization': _authToken!} : null,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return placeholder;
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder;
        },
      );
    } else {
      content = placeholder;
    }

    return ClipOval(child: SizedBox(width: size, height: size, child: content));
  }
}

class StaffAvatarUtils {
  static String initialsFrom(String firstName, String lastName) {
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
  }
}

// =====================================================
// LIST & CARD WIDGETS
// =====================================================

// STAFF CARD WIDGET
class StaffCardWidget extends StatelessWidget {
  final Staff staff;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleStatus;
  final String departmentName;
  final String positionTitle;

  const StaffCardWidget({
    super.key,
    required this.staff,
    this.onTap,
    this.onEdit,
    this.onToggleStatus,
    required this.departmentName,
    required this.positionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Photo
              StaffAvatar(
                photoUrl: staff.photoUrl,
                initials: StaffAvatarUtils.initialsFrom(
                  staff.firstName,
                  staff.lastName,
                ),
                radius: 30,
              ),

              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      positionTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      departmentName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              // Status & Actions
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: staff.isActive ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      staff.isActive ? 'Activo' : 'Inactivo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'toggle':
                          onToggleStatus?.call();
                          break;
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(PhosphorIcons.pencilSimple(), size: 18),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  staff.isActive
                                      ? PhosphorIcons.pause()
                                      : PhosphorIcons.play(),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(staff.isActive ? 'Desactivar' : 'Activar'),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// =====================================================
// FILTER & SEARCH WIDGETS - PARTE 2 DE 4 - ✅ CORREGIDA
// =====================================================

// FILTERS WIDGET - ✅ COMPLETAMENTE ACTUALIZADO Y CORREGIDO
class StaffFiltersWidget extends StatelessWidget {
  const StaffFiltersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffController>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar empleados...',
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
            ),
            onChanged: (value) {
              // Debounce search
              Future.delayed(const Duration(milliseconds: 500), () {
                controller.searchStaff(value);
              });
            },
          ),

          const SizedBox(height: 12),

          // Filter Chips - ✅ COMPLETAMENTE RENOVADO Y CORREGIDO CON PROTECCIÓN ADICIONAL
          Obx(() {
            final state = controller.state;
            // ✅ PROTECCIÓN ADICIONAL: Verificar que el estado esté completamente inicializado
            final safeIncludeInactive = state.includeInactive == true;
            final safeActiveFilter = state.activeFilter == true;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // ✅ FILTRO DE ESTADO MEJORADO (Activos/Inactivos/Todos)
                PopupMenuButton<String>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      // ✅ CAMBIO 2: Usar variables seguras
                      color: _getStatusFilterColor(
                        context,
                        safeActiveFilter,
                        safeIncludeInactive,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        // ✅ CAMBIO 3: Usar variables seguras
                        color: _getStatusFilterBorderColor(
                          context,
                          safeActiveFilter,
                          safeIncludeInactive,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          // ✅ CAMBIO 4: Usar variables seguras
                          _getStatusFilterIcon(
                            safeActiveFilter,
                            safeIncludeInactive,
                          ),
                          size: 16,
                          // ✅ CAMBIO 5: Usar variables seguras
                          color: _getStatusFilterIconColor(
                            context,
                            safeActiveFilter,
                            safeIncludeInactive,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          // ✅ CAMBIO 6: Usar variables seguras
                          _getStatusFilterText(
                            safeActiveFilter,
                            safeIncludeInactive,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            // ✅ CAMBIO 7: Usar variables seguras
                            color: _getStatusFilterTextColor(
                              context,
                              safeActiveFilter,
                              safeIncludeInactive,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          PhosphorIcons.caretDown(),
                          size: 16,
                          // ✅ CAMBIO 8: Usar variables seguras
                          color: _getStatusFilterIconColor(
                            context,
                            safeActiveFilter,
                            safeIncludeInactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem<String>(
                          value: 'active_only',
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.eye(),
                                size: 18,
                                color: Colors.green[600],
                              ),
                              const SizedBox(width: 12),
                              const Text('Solo Activos'),
                              const Spacer(),
                              // ✅ CAMBIO 9: Usar variables seguras
                              if (safeActiveFilter && !safeIncludeInactive)
                                Icon(
                                  PhosphorIcons.check(),
                                  size: 18,
                                  color: Colors.green[600],
                                ),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'inactive_only',
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.eyeSlash(),
                                size: 18,
                                color: Colors.red[600],
                              ),
                              const SizedBox(width: 12),
                              const Text('Solo Inactivos'),
                              const Spacer(),
                              // ✅ CAMBIO 10: Usar variables seguras
                              if (!safeActiveFilter && !safeIncludeInactive)
                                Icon(
                                  PhosphorIcons.check(),
                                  size: 18,
                                  color: Colors.red[600],
                                ),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'all',
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.usersThree(),
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              const Text('Todos (Activos e Inactivos)'),
                              const Spacer(),
                              // ✅ CAMBIO 11: Usar variables seguras
                              if (safeIncludeInactive)
                                Icon(
                                  PhosphorIcons.check(),
                                  size: 18,
                                  color: Colors.blue[600],
                                ),
                            ],
                          ),
                        ),
                      ],
                  onSelected:
                      (value) => _handleStatusFilterChange(controller, value),
                ),

                // ✅ FILTRO DE DEPARTAMENTO CORREGIDO
                if (state.departments.isNotEmpty)
                  PopupMenuButton<String?>(
                    key: ValueKey(state.selectedDepartmentId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            state.selectedDepartmentId != null
                                ? Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              state.selectedDepartmentId != null
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.buildings(),
                            size: 16,
                            color:
                                state.selectedDepartmentId != null
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            state.selectedDepartmentId == null
                                ? 'Todos los Departamentos'
                                : controller.getDepartmentName(
                                  state.selectedDepartmentId!,
                                ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color:
                                  state.selectedDepartmentId != null
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            PhosphorIcons.caretDown(),
                            size: 16,
                            color:
                                state.selectedDepartmentId != null
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                    itemBuilder:
                        (context) => [
                          PopupMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIcons.eraser(),
                                  size: 18,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                const Text('Todos los Departamentos'),
                                const Spacer(),
                                if (state.selectedDepartmentId == null)
                                  Icon(
                                    PhosphorIcons.check(),
                                    size: 18,
                                    color: Colors.blue[600],
                                  ),
                              ],
                            ),
                          ),

                          // Separador
                          const PopupMenuDivider(),

                          // Lista de departamentos
                          ...state.departments.map(
                            (dept) => PopupMenuItem<String?>(
                              value: dept.id, // ✅ VALOR String EXPLÍCITO
                              child: Row(
                                children: [
                                  Icon(
                                    PhosphorIcons.buildings(),
                                    size: 18,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      dept.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (state.selectedDepartmentId == dept.id)
                                    Icon(
                                      PhosphorIcons.check(),
                                      size: 18,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                    onSelected: (String? value) {
                      controller.updateDepartmentFilter(value);
                    },
                  ),

                // ✅ CONTADOR DE RESULTADOS MEJORADO
                if (state.staffList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.users(),
                          size: 14,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${state.filteredStaff.length} de ${state.staffList.length}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ✅ BOTÓN PARA LIMPIAR TODOS LOS FILTROS
                if (state.selectedDepartmentId != null ||
                    state.searchText.isNotEmpty ||
                    // ✅ CAMBIO 12: Usar variables seguras
                    (!safeActiveFilter && !safeIncludeInactive))
                  InkWell(
                    onTap: () => _clearAllFilters(controller),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.x(),
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Limpiar',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ✅ MÉTODOS HELPER PARA EL FILTRO DE ESTADO - TODOS CORREGIDOS
  void _handleStatusFilterChange(StaffController controller, String value) {
    //     print('🔄 Cambiando filtro de estado a: $value');

    switch (value) {
      case 'active_only':
        controller.setStatusFilter(activeOnly: true);
        break;
      case 'inactive_only':
        controller.setStatusFilter(inactiveOnly: true);
        break;
      case 'all':
        controller.setStatusFilter(showAll: true);
        break;
    }

    // ✅ NO LLAMAR refreshData() ADICIONAL - setStatusFilter YA LO HACE
    //     print('✅ Filtro de estado aplicado');
  }

  void _clearAllFilters(StaffController controller) {
    //     print('🧹 Limpiando todos los filtros');
    // ✅ SOLO LLAMAR clearAllFilters - YA INCLUYE LA RECARGA
    controller.clearAllFilters();
    //     print('✅ Filtros limpiados');
  }

  // ✅ MÉTODOS HELPER CORREGIDOS - PARÁMETROS ACTUALIZADOS
  Color _getStatusFilterColor(
    BuildContext context,
    bool activeFilter,
    bool includeInactive,
  ) {
    if (includeInactive) return Theme.of(context).primaryColor.withOpacity(0.1);
    if (activeFilter) return Colors.green[50]!;
    return Colors.red[50]!;
  }

  Color _getStatusFilterBorderColor(
    BuildContext context,
    bool activeFilter,
    bool includeInactive,
  ) {
    if (includeInactive) return Theme.of(context).primaryColor.withOpacity(0.5);
    if (activeFilter) return Colors.green[300]!;
    return Colors.red[300]!;
  }

  IconData _getStatusFilterIcon(bool activeFilter, bool includeInactive) {
    if (includeInactive) return PhosphorIcons.usersThree();
    if (activeFilter) return PhosphorIcons.eye();
    return PhosphorIcons.eyeSlash();
  }

  Color _getStatusFilterIconColor(
    BuildContext context,
    bool activeFilter,
    bool includeInactive,
  ) {
    if (includeInactive) return Theme.of(context).primaryColor;
    if (activeFilter) return Colors.green[600]!;
    return Colors.red[600]!;
  }

  String _getStatusFilterText(bool activeFilter, bool includeInactive) {
    if (includeInactive) return 'Todos';
    if (activeFilter) return 'Solo Activos';
    return 'Solo Inactivos';
  }

  Color _getStatusFilterTextColor(
    BuildContext context,
    bool activeFilter,
    bool includeInactive,
  ) {
    if (includeInactive) return Theme.of(context).primaryColor;
    if (activeFilter) return Colors.green[700]!;
    return Colors.red[700]!;
  }
}
// =====================================================
// STATE WIDGETS & FORM WIDGETS - PARTE 3 DE 4
// =====================================================

// EMPTY STATE WIDGET
class StaffEmptyStateWidget extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback? onAddStaff;
  final VoidCallback? onClearFilters;

  const StaffEmptyStateWidget({
    super.key,
    this.hasFilters = false,
    this.onAddStaff,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters
                  ? PhosphorIcons.magnifyingGlassMinus()
                  : PhosphorIcons.users(),
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No se encontraron empleados'
                  : 'No hay empleados registrados',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Intenta ajustar los filtros de búsqueda'
                  : 'Agrega el primer empleado para comenzar',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: Icon(PhosphorIcons.eraser()),
                label: const Text('Limpiar Filtros'),
              )
            else
              ElevatedButton.icon(
                onPressed: onAddStaff,
                icon: Icon(PhosphorIcons.plus()),
                label: const Text('Agregar Empleado'),
              ),
          ],
        ),
      ),
    );
  }
}

// ERROR WIDGET
class StaffErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const StaffErrorWidget({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.warningCircle(),
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Oops! Algo salió mal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(PhosphorIcons.arrowsClockwise()),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// FORM WIDGETS
// =====================================================

// TEXT FIELD WIDGET
class StaffTextFieldWidget extends StatefulWidget {
  final String label;
  final String initialValue;
  final Function(String) onChanged;
  final String? errorText;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? prefixText;
  final TextCapitalization textCapitalization;
  final bool enabled;

  const StaffTextFieldWidget({
    super.key,
    required this.label,
    this.initialValue = '',
    required this.onChanged,
    this.errorText,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixText,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  @override
  State<StaffTextFieldWidget> createState() => _StaffTextFieldWidgetState();
}

class _StaffTextFieldWidgetState extends State<StaffTextFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(StaffTextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo actualizar si el valor cambió externamente
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      final cursorPosition = _controller.selection.baseOffset;
      _controller.text = widget.initialValue;
      // Restaurar posición del cursor si es válida
      if (cursorPosition <= _controller.text.length) {
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: cursorPosition),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: widget.prefixText,
        border: const OutlineInputBorder(),
        errorText: widget.errorText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabled: widget.enabled,
      ),
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      textCapitalization: widget.textCapitalization,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// DROPDOWN WIDGET
class StaffDropdownWidget<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final Function(T?)? onChanged;
  final String? errorText;
  final bool enabled;

  const StaffDropdownWidget({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabled: enabled,
      ),
      items: items,
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
    );
  }
}

// DATE PICKER WIDGET
class StaffDatePickerWidget extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final bool allowClear;

  const StaffDatePickerWidget({
    super.key,
    required this.label,
    this.selectedDate,
    required this.onDateSelected,
    this.allowClear = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDatePicker(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.calendar()),
              if (allowClear && selectedDate != null)
                IconButton(
                  icon: Icon(PhosphorIcons.x(), size: 18),
                  onPressed: () => onDateSelected(DateTime.now()),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        child: Text(
          selectedDate != null
              ? _formatDate(selectedDate!)
              : 'Seleccionar fecha',
          style: TextStyle(
            color:
                selectedDate != null
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// PHOTO PICKER WIDGET
class StaffPhotoPickerWidget extends StatelessWidget {
  final String? photoUrl;
  final Function(String?) onPhotoSelected;
  final int? userId;

  const StaffPhotoPickerWidget({
    super.key,
    this.photoUrl,
    this.userId,
    required this.onPhotoSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                StaffAvatar(photoUrl: photoUrl, initials: '', radius: 60),
                if (photoUrl == null || photoUrl!.isEmpty)
                  Icon(PhosphorIcons.camera(), size: 40, color: Colors.white),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.camera(),
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image != null) {
        // Mostrar mensaje de carga (si hay contexto disponible)
        final ctx = Get.context;
        if (ctx != null) {
          NetErrorMessages.showMessage(ctx, 'Subiendo foto...', success: true);
        }

        final url = await StaffPhotoService.subirFotoPerfil(
          image,
          userId: userId,
        );

        if (url != null && url.isNotEmpty) {
          onPhotoSelected(url);
          if (ctx != null) {
            NetErrorMessages.showMessage(
              ctx,
              'Foto subida correctamente',
              success: true,
            );
          }
        } else {
          if (ctx != null) {
            NetErrorMessages.showMessage(
              ctx,
              'Error subiendo foto',
              success: false,
            );
          }
        }
      }
    } catch (e) {
      final ctx = Get.context;
      if (ctx != null) {
        NetErrorMessages.showNetError(ctx, e, contexto: 'subir foto de perfil');
      }
    }
  }
}

// EXPANDABLE SECTION WIDGET
class StaffExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const StaffExpandableSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<StaffExpandableSection> createState() => _StaffExpandableSectionState();
}

class _StaffExpandableSectionState extends State<StaffExpandableSection> {
  late bool isExpanded;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => isExpanded = !isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(widget.icon, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? PhosphorIcons.caretUp()
                        : PhosphorIcons.caretDown(),
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: widget.children),
            ),
        ],
      ),
    );
  }
}
// =====================================================
// DETAIL PAGE WIDGETS & MESSAGE WIDGETS - PARTE 4 DE 4 (FINAL)
// =====================================================

// DETAIL HEADER WIDGET
class StaffDetailHeaderWidget extends StatelessWidget {
  final Staff staff;
  final String departmentName;
  final String positionTitle;

  const StaffDetailHeaderWidget({
    super.key,
    required this.staff,
    required this.departmentName,
    required this.positionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Photo
            StaffAvatar(
              photoUrl: staff.photoUrl,
              initials: StaffAvatarUtils.initialsFrom(
                staff.firstName,
                staff.lastName,
              ),
              radius: 60,
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              staff.fullName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Position and Department
            Text(
              positionTitle,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              departmentName,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Staff Code
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Código: ${staff.staffCode}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// INFO CARD WIDGET
class StaffInfoCardWidget extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const StaffInfoCardWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// INFO ROW WIDGET
class StaffInfoRowWidget extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StaffInfoRowWidget(
    this.label,
    this.value, {
    super.key,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color:
                    valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: valueColor != null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// MESSAGE & FEEDBACK WIDGETS
// =====================================================

// ✅ WIDGET PARA MOSTRAR MENSAJES DE ÉXITO
class StaffSuccessMessageWidget extends StatelessWidget {
  final String message;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const StaffSuccessMessageWidget({
    super.key,
    required this.message,
    this.icon,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? PhosphorIcons.checkCircle(),
            color: Colors.green[600],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(PhosphorIcons.x(), color: Colors.green[600]),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

// ✅ WIDGET PARA MOSTRAR MENSAJES DE ERROR DETALLADOS
class StaffErrorMessageWidget extends StatelessWidget {
  final String message;
  final String? details;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const StaffErrorMessageWidget({
    super.key,
    required this.message,
    this.details,
    this.icon,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon ?? PhosphorIcons.warningCircle(),
                color: Colors.red[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: Icon(PhosphorIcons.x(), color: Colors.red[600]),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (details != null) ...[
            const SizedBox(height: 8),
            Text(
              details!,
              style: TextStyle(color: Colors.red[600], fontSize: 12),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(PhosphorIcons.arrowsClockwise(), size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ✅ WIDGET PARA MOSTRAR ESTADO DE GUARDANDO
class StaffSavingIndicatorWidget extends StatelessWidget {
  final String message;

  const StaffSavingIndicatorWidget({
    super.key,
    this.message = 'Guardando empleado...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ WIDGET PARA MOSTRAR OPCIÓN DE REINTENTAR
class StaffRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const StaffRetryWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.warning(),
                color: Colors.orange[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error Temporal',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.orange[700], fontSize: 14),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(PhosphorIcons.arrowsClockwise(), size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// FIN DEL ARCHIVO staff_widgets.dart
// =====================================================
