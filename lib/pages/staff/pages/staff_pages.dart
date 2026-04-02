// =====================================================
// UI LAYER - Pages + Forms - LIMPIO Y INDEPENDIZADO
// =====================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/main.dart';
// ✅ Importar MyApp para acceder a messengerKey
import '../domain/staff_domain.dart';
import '../models/staff_model.dart';
import '../presentation/staff_presentation.dart';
import '../widgets/staff_widgets.dart';
import '../widgets/campo_departamento.dart';
import '../widgets/campo_position.dart';

// =====================================================
// STAFF LIST PAGE (Main Page)
// =====================================================

class StaffListPage extends StatelessWidget {
  const StaffListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // ✅ BOTÓN CREAR EMPLEADO EN EL HEADER
          IconButton(
            icon: Icon(PhosphorIcons.plus()),
            tooltip: 'Agregar Empleado',
            onPressed: () => _navigateToForm(context),
          ),
          // ✅ OPCIONES DE EXPORTAR E IMPORTAR OCULTAS
          // Las opciones están comentadas para ocultarlas:

          // Export Options - OCULTO
          /*
        PopupMenuButton<String>(
            icon: Icon(PhosphorIcons.downloadSimple()),
            tooltip: 'Exportar',
            onSelected: (value) {
                switch (value) {
                    case 'excel':
                        controller.exportToExcel();
                        break;
                    case 'csv':
                        controller.exportToCSV();
                        break;
                }
            },
            itemBuilder:
                (context) => [
                    const PopupMenuItem(
                        value: 'excel',
                        child: Row(
                            children: [
                                Icon(PhosphorIcons.table()),
                                SizedBox(width: 8),
                                Text('Exportar Excel'),
                            ],
                        ),
                    ),
                    const PopupMenuItem(
                        value: 'csv',
                        child: Row(
                            children: [
                                Icon(PhosphorIcons.fileText()),
                                SizedBox(width: 8),
                                Text('Exportar CSV'),
                            ],
                        ),
                    ),
                ],
        ),
        */

          // Import Button - OCULTO
          /*
        IconButton(
            icon: Icon(PhosphorIcons.uploadSimple()),
            tooltip: 'Importar',
            onPressed: () => controller.importStaff(),
        ),
        */

          // Refresh Button - MANTENER VISIBLE
          IconButton(
            icon: Icon(PhosphorIcons.arrowsClockwise()),
            tooltip: 'Actualizar',
            onPressed: controller.refreshData,
          ),
        ],
      ),

      body: Column(
        children: [
          // Filters Section - Widget independizado
          const StaffFiltersWidget(),

          // Content Area
          Expanded(
            child: Obx(() {
              final state = controller.state;

              // Loading State
              if (state.isLoading && !state.hasData) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Cargando empleados...'),
                    ],
                  ),
                );
              }

              // Error State - Widget independizado
              if (state.hasError && !state.hasData) {
                return StaffErrorWidget(
                  error: state.error!,
                  onRetry: controller.loadInitialData,
                );
              }

              final filteredStaff = state.filteredStaff;

              // Empty State - Widget independizado
              if (filteredStaff.isEmpty) {
                return StaffEmptyStateWidget(
                  hasFilters:
                      state.searchText.isNotEmpty ||
                      !state.activeFilter ||
                      state.selectedDepartmentId != null,
                  onAddStaff: () => _navigateToForm(context),
                  onClearFilters: () => _clearAllFilters(context, controller),
                );
              }

              // Staff List
              return RefreshIndicator(
                onRefresh: controller.refreshData,
                child: Stack(
                  children: [
                    // List using StaffCardWidget
                    ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredStaff.length,
                      itemBuilder: (context, index) {
                        final staff = filteredStaff[index];
                        return StaffCardWidget(
                          staff: staff,
                          onTap: () => _navigateToDetail(context, staff),
                          onEdit: () => _navigateToForm(context, staff: staff),
                          onToggleStatus:
                              () => _showToggleStatusDialog(
                                context,
                                staff,
                                controller,
                              ),
                          departmentName: controller.getDepartmentName(
                            staff.departmentId,
                          ),
                          positionTitle: controller.getPositionTitle(
                            staff.positionId,
                          ),
                        );
                      },
                    ),

                    // Loading Overlay
                    if (state.isProcessing && state.hasData)
                      Container(
                        color: Colors.black26,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Helper methods
  void _navigateToForm(BuildContext context, {Staff? staff}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => StaffFormPage(staff: staff)),
    );
  }

  void _navigateToDetail(BuildContext context, Staff staff) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => StaffDetailPage(staff: staff)),
    );
  }

  void _clearAllFilters(BuildContext context, StaffController controller) {
    //     print('🧹 Limpiando todos los filtros desde la vista...');

    // ✅ USAR EL MÉTODO CORRECTO DEL CONTROLLER
    controller.clearAllFilters();

    // ✅ MOSTRAR FEEDBACK AL USUARIO CON GET.SNACKBAR
    Get.snackbar(
      'Filtros',
      'Todos los filtros han sido limpiados',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Theme.of(context).primaryColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: Icon(PhosphorIcons.eraser(), color: Colors.white),
    );
  }

  void _showToggleStatusDialog(
    BuildContext context,
    Staff staff,
    StaffController controller,
  ) {
    final bool isActive = staff.isActive;
    final String action = isActive ? 'desactivar' : 'activar';
    final String capitalizedAction =
        action[0].toUpperCase() + action.substring(1);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isActive ? PhosphorIcons.pauseCircle() : PhosphorIcons.playCircle(),
                  color: isActive ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text('$capitalizedAction Empleado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Estás seguro que deseas $action a ${staff.fullName}?',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isActive ? Colors.red : Colors.green).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isActive ? Colors.red : Colors.green).withOpacity(
                        0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.info(),
                        size: 16,
                        color: isActive ? Colors.red[700] : Colors.green[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isActive
                              ? 'El empleado se marcará como inactivo y no aparecerá en las listas principales.'
                              : 'El empleado se marcará como activo y aparecerá en las listas principales.',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isActive ? Colors.red[700] : Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();

                  // ✅ MOSTRAR INDICADOR DE CARGA
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${capitalizedAction}ndo empleado...'),
                        ],
                      ),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  );

                  // ✅ EJECUTAR EL CAMBIO DE ESTADO
                  await controller.toggleStaffStatus(staff.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(isActive ? PhosphorIcons.pause() : PhosphorIcons.play()),
                label: Text(capitalizedAction),
              ),
            ],
          ),
    );
  }
}

// =====================================================
// STAFF FORM PAGE (Create/Edit)
// =====================================================

class StaffFormPage extends StatefulWidget {
  final Staff? staff;

  const StaffFormPage({super.key, this.staff});

  @override
  State<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends State<StaffFormPage> {
  late final StaffFormController formController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    formController = Get.put(StaffFormController());

    if (widget.staff != null) {
      formController.loadStaff(widget.staff!);
    } else {
      formController.clearForm();
    }

    // ✅ ESCUCHAR CAMBIOS EN formSuccessful CON MÁS CONTROL
    // ✅ ESCUCHAR CAMBIOS EN formSuccessful CON MÁS CONTROL Y DEBUG
    ever(formController.formSuccessful, (bool success) {
      //       print('🎯 formSuccessful cambió a: $success');
      if (success && mounted) {
        //         print('✅ Formulario exitoso, cerrando después de mostrar mensaje...');
        // ✅ DARLE TIEMPO AL USUARIO PARA VER EL MENSAJE DE ÉXITO
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            //             print('🔙 Cerrando formulario después de éxito confirmado');
            Navigator.of(
              context,
            ).pop(true); // ✅ Retornar true para indicar éxito
          }
        });
      } else {
        //         print('⏸️ Formulario NO se cerrará (success: $success, mounted: $mounted)');
      }
    });
  }

  // ✅ AGREGAR ESTOS MÉTODOS DENTRO DE LA CLASE _StaffFormPageState
  void _showFormErrorsSnackbar(
    BuildContext context,
    Map<String, String> errors,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por favor corrige los errores en el formulario:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...errors.entries.map((entry) => Text('• ${entry.value}')),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _retryAfterServerError() {
    //     print('🔄 Usuario solicitó reintentar después de error de servidor');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Reintentando guardado...'),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );

    // ✅ AHORA SÍ TIENE ACCESO AL CONTEXT PORQUE ESTÁ DENTRO DE LA CLASE
    _saveStaff(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.staff != null;
    final mainController = Get.find<StaffController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Empleado' : 'Nuevo Empleado'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Save Button - CORREGIDO con debugging
          Obx(() {
            final isValid = formController.isFormValid.value;
            final isProcessing =
                mainController.state.isCreating ||
                mainController.state.isUpdating;

            // Debug del estado del botón
            //             print('🔘 Botón estado - Valid: $isValid, Processing: $isProcessing');

            return TextButton(
              onPressed:
                  isProcessing
                      ? null // Deshabilitar si está procesando
                      : () {
                        //                         print('🎯 Botón GUARDAR presionado - Valid: $isValid');
                        _saveStaff(context);
                      },
              child:
                  isProcessing
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        'GUARDAR',
                        style: TextStyle(
                          color: Colors.white, // Siempre blanco
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            );
          }),

          // ✅ BOTÓN DEBUG OPCIONAL (remover en producción)
          if (false) // Cambiar a false para ocultar
            IconButton(
              icon: Icon(PhosphorIcons.bug()),
              onPressed: () => formController.debugFormState(),
              tooltip: 'Debug Form',
            ),
        ],
      ),
      body: Obx(() {
        final state = mainController.state;

        if (state.isCreating || state.isUpdating) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Guardando empleado...'),
              ],
            ),
          );
        }

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Photo Section - Widget independizado
              StaffPhotoPickerWidget(
                photoUrl: formController.photoUrl.value,
                onPhotoSelected: (url) => formController.photoUrl.value = url,
              ),

              const SizedBox(height: 24),

              // Personal Information Section
              _buildPersonalInformationSection(),

              const SizedBox(height: 20),

              // Work Information Section
              _buildWorkInformationSection(),

              const SizedBox(height: 20),

              // Additional Information Section - Widget independizado
              StaffExpandableSection(
                title: 'Información Adicional',
                icon: PhosphorIcons.info(),
                children: _buildAdditionalInformationFields(),
              ),

              const SizedBox(height: 20),

              // Status Section
              _buildStatusSection(),

              const SizedBox(height: 32),

              // Form Validation Info
              _buildValidationErrorsCard(),
            ],
          ),
        );
      }),
    );
  }

  // Personal Information Section
  Widget _buildPersonalInformationSection() {
    return _buildSectionCard(
      context: context,
      title: 'Información Personal',
      icon: PhosphorIcons.user(),
      children: [
        // Names Row - ❌ SIN Obx() - Son TextEditingControllers
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: formController.firstNameController,
                decoration: InputDecoration(
                  labelText: 'Nombres *',
                  border: const OutlineInputBorder(),
                  errorText: formController.formErrors['firstName'],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (value) {
                  Future.microtask(() {
                    if (mounted) formController.forceValidation();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: formController.lastNameController,
                decoration: InputDecoration(
                  labelText: 'Apellidos *',
                  border: const OutlineInputBorder(),
                  errorText: formController.formErrors['lastName'],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (value) {
                  Future.microtask(() {
                    if (mounted) formController.forceValidation();
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Email - ❌ SIN Obx() - Es TextEditingController
        TextFormField(
          controller: formController.emailController,
          decoration: InputDecoration(
            labelText: 'Email *',
            border: const OutlineInputBorder(),
            errorText: formController.formErrors['email'],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: (value) {
            Future.microtask(() {
              if (mounted) formController.forceValidation();
            });
          },
        ),

        const SizedBox(height: 16),

        // Phone - ❌ SIN Obx() - Es TextEditingController
        TextFormField(
          controller: formController.phoneController,
          decoration: const InputDecoration(
            labelText: 'Teléfono',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 16),

        // Identification Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Obx(
                // ✅ MANTENER Obx() - identificationType ES observable
                () => StaffDropdownWidget<IdentificationType>(
                  label: 'Tipo de Documento *',
                  value: formController.identificationType.value,
                  items:
                      IdentificationType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.displayName),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) =>
                          formController.identificationType.value = value!,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              // ✅ SIN Obx() - usar TextField directo
              child: TextFormField(
                controller: formController.identificationController,
                decoration: InputDecoration(
                  labelText: 'Número de Documento *',
                  border: const OutlineInputBorder(),
                  errorText: formController.formErrors['identificationNumber'],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  Future.microtask(() {
                    if (mounted) formController.forceValidation();
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Birth Date - ✅ MANTENER Obx() - birthDate ES observable
        Obx(
          () => StaffDatePickerWidget(
            label: 'Fecha de Nacimiento',
            selectedDate: formController.birthDate.value,
            onDateSelected: (date) => formController.birthDate.value = date,
            allowClear: true,
          ),
        ),
      ],
    );
  }

  // Work Information Section
  Widget _buildWorkInformationSection() {
    final mainController = Get.find<StaffController>();

    return _buildSectionCard(
      context: context,
      title: 'Información Laboral',
      icon: PhosphorIcons.briefcase(),
      children: [
        // Department Dropdown - ✅ MANTENER Obx() - departmentId ES observable
        Obx(
          () => CampoDepartamento(
            departamentoId:
                formController.departmentId.value != null
                    ? int.tryParse(formController.departmentId.value!)
                    : null,
            onChanged: (departmentId) {
              formController.departmentId.value = departmentId?.toString();
              formController.positionId.value = null; // Reset position
            },
            validator: (_) => formController.formErrors['departmentId'],
            enabled:
                !mainController.state.isCreating &&
                !mainController.state.isUpdating,
          ),
        ),

        const SizedBox(height: 16),

        // Position Dropdown - ✅ MANTENER Obx() - positionId ES observable
        Obx(
          () => CampoPosition(
            posicionId:
                formController.positionId.value != null
                    ? int.tryParse(formController.positionId.value!)
                    : null,
            departamentoId:
                formController.departmentId.value != null
                    ? int.tryParse(formController.departmentId.value!)
                    : null,
            onChanged: (positionId) {
              formController.positionId.value = positionId?.toString();
            },
            validator: (_) => formController.formErrors['positionId'],
            enabled:
                !mainController.state.isCreating &&
                !mainController.state.isUpdating &&
                formController.departmentId.value != null,
          ),
        ),

        const SizedBox(height: 16),

        // Especialidad Dropdown - ✅ MANTENER Obx() - especialidadId ES observable
        Obx(() {
          final specialties = mainController.state.specialties;

          return DropdownButtonFormField<String>(
            initialValue: formController.especialidadId.value,
            decoration: InputDecoration(
              labelText: 'Especialidad (Opcional)',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              errorText: formController.formErrors['id_especialidad'],
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Ninguna'),
              ),
              ...specialties.map((s) {
                return DropdownMenuItem<String>(
                  value: s['id'].toString(),
                  child: Text(s['nombre']?.toString() ?? 'Sin nombre'),
                );
              }),
            ],
            onChanged: (value) {
              formController.especialidadId.value = value;
            },
          );
        }),

        const SizedBox(height: 16),

        // Hire Date - ✅ MANTENER Obx() - hireDate ES observable
        Obx(
          () => StaffDatePickerWidget(
            label: 'Fecha de Ingreso *',
            selectedDate: formController.hireDate.value,
            onDateSelected: (date) => formController.hireDate.value = date,
          ),
        ),

        const SizedBox(height: 16),

        // Salary - ❌ SIN Obx() - salaryController es TextEditingController
        TextFormField(
          controller: formController.salaryController,
          decoration: const InputDecoration(
            labelText: 'Salario',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // Additional Information Fields
  List<Widget> _buildAdditionalInformationFields() {
    return [
      // Address - ❌ SIN Obx() - addressController es TextEditingController
      TextFormField(
        controller: formController.addressController,
        decoration: const InputDecoration(
          labelText: 'Dirección',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        maxLines: 2,
      ),

      const SizedBox(height: 16),

      // Emergency Contact Name - ❌ SIN Obx()
      TextFormField(
        controller: formController.emergencyNameController,
        decoration: const InputDecoration(
          labelText: 'Contacto de Emergencia',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        textCapitalization: TextCapitalization.words,
      ),

      const SizedBox(height: 16),

      // Emergency Contact Phone - ❌ SIN Obx()
      TextFormField(
        controller: formController.emergencyPhoneController,
        decoration: const InputDecoration(
          labelText: 'Teléfono de Emergencia',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: TextInputType.phone,
      ),
    ];
  }

  // Status Section
  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          // ✅ MANTENER - isActive ES observable
          () => SwitchListTile(
            title: const Text('Empleado Activo'),
            subtitle: Text(
              formController.isActive.value
                  ? 'El empleado está activo en el sistema'
                  : 'El empleado está inactivo en el sistema',
            ),
            value: formController.isActive.value,
            onChanged: (value) => formController.isActive.value = value,
            secondary: Icon(
              formController.isActive.value ? PhosphorIcons.checkCircle() : PhosphorIcons.xCircle(),
              color: formController.isActive.value ? Colors.green : Colors.red,
            ),
          ),
        ),
      ),
    );
  }

  // Validation Errors Card
  Widget _buildValidationErrorsCard() {
    return Obx(() {
      // ✅ MANTENER - formErrors ES observable
      if (formController.formErrors.isNotEmpty) {
        return Card(
          color: Colors.red[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.warningCircle(), color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Errores en el formulario:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...formController.formErrors.values.map(
                  (error) => Text(
                    '• $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  // Helper method for building section cards
  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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

  // ✅ MÉTODO SAVE MEJORADO CON MEJOR MANEJO DE ERRORES Y MENSAJES
  Future<void> _saveStaff(BuildContext context) async {
    //     print('🎯 Botón GUARDAR presionado');
    // ✅ DEBUG MEJORADO DEL ESTADO DEL FORMULARIO
    //     print('🔍 ESTADO ANTES DE VALIDAR:');
    formController.debugFormState();

    // ✅ FORZAR VALIDACIÓN ANTES DE VERIFICAR
    //     print('🔄 Forzando validación antes de verificar...');
    formController.forceValidation();

    //     print('🔍 ESTADO DESPUÉS DE FORZAR VALIDACIÓN:');
    formController.debugFormState();
    // Debug del estado del formulario
    formController.debugFormState();

    if (!formController.isFormValid.value) {
      //       print('❌ Formulario no válido, mostrando errores');
      //       print('❌ Detalles de errores: ${formController.formErrors}');

      // ✅ VERIFICAR SI HAY ERRORES REALES O ES UN PROBLEMA DE VALIDACIÓN
      if (formController.formErrors.isEmpty) {
        //         print('⚠️ PROBLEMA: Formulario inválido pero sin errores específicos');
        //         print('🔧 Forzando re-validación para obtener errores reales...');
        formController.forceValidation();

        // Si después de forzar validación sigue sin errores, permitir guardar
        if (formController.formErrors.isEmpty) {
          //           print('✅ Después de re-validación no hay errores, permitiendo guardar...');
          // ✅ NO RETORNAR, CONTINUAR CON EL GUARDADO
        } else {
          //           print('❌ Después de re-validación se encontraron errores: ${formController.formErrors}');
          // Mostrar los errores y retornar
          _showFormErrorsSnackbar(context, formController.formErrors);
          return;
        }
      } else {
        // Hay errores específicos, mostrarlos
        _showFormErrorsSnackbar(context, formController.formErrors);
        return;
      }
    }

    try {
      //       print('📝 Iniciando proceso de guardado...');

      // ✅ MOSTRAR MENSAJE DE "GUARDANDO..." MIENTRAS PROCESA
      MyApp.showSnackBar(
        'Guardando empleado...',
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 10),
      );

      await formController.saveStaff();
      //       print('✅ Proceso de guardado completado');

      // ✅ OCULTAR EL SNACKBAR DE "GUARDANDO..."
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      //       print('❌ Error en _saveStaff: $e');

      // ✅ OCULTAR EL SNACKBAR DE "GUARDANDO..."
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // ✅ MOSTRAR ERROR ESPECÍFICO AL USUARIO CON DIALOG
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(PhosphorIcons.warningCircle(), color: Colors.red),
                  SizedBox(width: 8),
                  Text('Error al Guardar'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ocurrió un error inesperado al guardar el empleado:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      e.toString(),
                      style: TextStyle(color: Colors.red[700], fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Por favor intente nuevamente. Si el problema persiste, contacte al soporte técnico.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
    }
  }

  // ✅ MÉTODO PARA DEBUG MANUAL (Opcional - para testing)
  void _debugForm() {
    //     print('🔍 DEBUG MANUAL - Estado del formulario:');
    formController.forceValidation();
  }

  @override
  void dispose() {
    Get.delete<StaffFormController>();
    super.dispose();
  }
}

// =====================================================
// STAFF DETAIL PAGE
// =====================================================

class StaffDetailPage extends StatelessWidget {
  final Staff staff;

  const StaffDetailPage({super.key, required this.staff});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(staff.fullName),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.pencilSimple()),
            tooltip: 'Editar',
            onPressed: () => _navigateToEdit(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'toggle_status':
                  _showToggleStatusDialog(context, staff, controller);
                  break;
                case 'view_history':
                  MyApp.showSnackBar('Historial próximamente disponible');
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'toggle_status',
                    child: Row(
                      children: [
                        Icon(staff.isActive ? PhosphorIcons.pause() : PhosphorIcons.play()),
                        const SizedBox(width: 8),
                        Text(staff.isActive ? 'Desactivar' : 'Activar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'view_history',
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.clockCounterClockwise()),
                        SizedBox(width: 8),
                        Text('Ver Historial'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with photo and basic info - Widget independizado
            StaffDetailHeaderWidget(
              staff: staff,
              departmentName: controller.getDepartmentName(staff.departmentId),
              positionTitle: controller.getPositionTitle(staff.positionId),
            ),

            const SizedBox(height: 24),

            // Personal Information Card - Widget independizado
            StaffInfoCardWidget(
              title: 'Información Personal',
              icon: PhosphorIcons.user(),
              children: [
                StaffInfoRowWidget('Email', staff.email),
                StaffInfoRowWidget('Teléfono', staff.phone ?? 'No registrado'),
                StaffInfoRowWidget(
                  'Documento',
                  '${staff.identificationType.displayName}: ${staff.identificationNumber}',
                ),
                // Safe access to StaffModel properties
                if (staff is StaffModel)
                  ..._buildStaffModelFields(staff as StaffModel),
              ],
            ),

            const SizedBox(height: 16),

            // Work Information Card - Widget independizado
            StaffInfoCardWidget(
              title: 'Información Laboral',
              icon: PhosphorIcons.briefcase(),
              children: [
                StaffInfoRowWidget('Código', staff.staffCode),
                StaffInfoRowWidget(
                  'Departamento',
                  controller.getDepartmentName(staff.departmentId),
                ),
                StaffInfoRowWidget(
                  'Cargo',
                  controller.getPositionTitle(staff.positionId),
                ),
                if (staff is StaffModel &&
                    (staff as StaffModel).especialidadNombre != null)
                  StaffInfoRowWidget(
                    'Especialidad',
                    (staff as StaffModel).especialidadNombre!,
                  ),
                StaffInfoRowWidget(
                  'Fecha de Ingreso',
                  _formatDate(staff.hireDate),
                ),
                StaffInfoRowWidget(
                  'Estado',
                  staff.isActive ? 'Activo' : 'Inactivo',
                  valueColor: staff.isActive ? Colors.green : Colors.red,
                ),
                if (staff.salary != null)
                  StaffInfoRowWidget(
                    'Salario',
                    '\$${staff.salary!.toStringAsFixed(2)}',
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Emergency Contact (if available)
            ..._buildEmergencyContactCard(staff),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToEdit(context),
                    icon: Icon(PhosphorIcons.pencilSimple()),
                    label: const Text('Editar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        () =>
                            _showToggleStatusDialog(context, staff, controller),
                    icon: Icon(staff.isActive ? PhosphorIcons.pause() : PhosphorIcons.play()),
                    label: Text(staff.isActive ? 'Desactivar' : 'Activar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor:
                          staff.isActive ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // System Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información del Sistema',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaffInfoRowWidget(
                      'Creado',
                      _formatDateTime(staff.createdAt),
                    ),
                    StaffInfoRowWidget(
                      'Última Actualización',
                      _formatDateTime(staff.updatedAt),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => StaffFormPage(staff: staff)),
    );
  }

  void _showToggleStatusDialog(
    BuildContext context,
    Staff staff,
    StaffController controller,
  ) {
    final bool isActive = staff.isActive;
    final String action = isActive ? 'desactivar' : 'activar';
    final String capitalizedAction =
        action[0].toUpperCase() + action.substring(1);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('$capitalizedAction Empleado'),
            content: Text(
              '¿Estás seguro que deseas $action a ${staff.fullName}?\n\n'
              'Esta acción ${isActive ? 'ocultará' : 'mostrará'} al empleado en las listas principales.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  controller.toggleStaffStatus(staff.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.red : Colors.green,
                ),
                child: Text(capitalizedAction),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}'
        '/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildStaffModelFields(StaffModel staffModel) {
    final List<Widget> widgets = [];

    if (staffModel.birthDate != null) {
      widgets.add(
        StaffInfoRowWidget(
          'Fecha de Nacimiento',
          _formatDate(staffModel.birthDate!),
        ),
      );
    }

    if (staffModel.address != null && staffModel.address!.isNotEmpty) {
      widgets.add(StaffInfoRowWidget('Dirección', staffModel.address!));
    }

    return widgets;
  }

  List<Widget> _buildEmergencyContactCard(Staff staff) {
    if (staff is! StaffModel) return [];

    final staffModel = staff;

    if (staffModel.emergencyContactName == null &&
        staffModel.emergencyContactPhone == null) {
      return [];
    }

    final List<Widget> children = [];

    if (staffModel.emergencyContactName != null &&
        staffModel.emergencyContactName!.isNotEmpty) {
      children.add(
        StaffInfoRowWidget('Nombre', staffModel.emergencyContactName!),
      );
    }

    if (staffModel.emergencyContactPhone != null &&
        staffModel.emergencyContactPhone!.isNotEmpty) {
      children.add(
        StaffInfoRowWidget('Teléfono', staffModel.emergencyContactPhone!),
      );
    }

    if (children.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      StaffInfoCardWidget(
        title: 'Contacto de Emergencia',
        icon: PhosphorIcons.firstAid(),
        children: children,
      ),
    ];
  }
}
