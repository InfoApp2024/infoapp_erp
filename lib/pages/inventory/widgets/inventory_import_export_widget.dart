// lib/pages/inventory/widgets/inventory_import_export_widget.dart

import '../services/inventory_api_service.dart';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import 'package:file_picker/file_picker.dart';

import '../models/inventory_item_model.dart';
import '../models/inventory_category_model.dart';
import '../models/inventory_supplier_model.dart';

// Opciones de exportación
class ExportOptions {
  final List<String> fields;
  final String format;
  final String dateFormat;
  final bool includeHeaders;
  final String encoding;

  const ExportOptions({
    this.fields = const [],
    this.format = 'csv',
    this.dateFormat = 'yyyy-MM-dd',
    this.includeHeaders = true,
    this.encoding = 'utf-8',
  });
}

// Widget principal para importación y exportación
class InventoryImportExportWidget extends StatefulWidget {
  final Function(File, ImportOptions)? onImport;
  final Function(List<InventoryItem>, ExportOptions)? onExport;
  final Function()? onRefresh;
  final List<InventoryItem> items;
  final List<InventoryCategory> categories;
  final List<InventorySupplier> suppliers;

  const InventoryImportExportWidget({
    super.key,
    this.onImport,
    this.onExport,
    this.onRefresh,
    this.items = const [],
    this.categories = const [],
    this.suppliers = const [],
  });

  @override
  State<InventoryImportExportWidget> createState() =>
      _InventoryImportExportWidgetState();
}

class _InventoryImportExportWidgetState
    extends State<InventoryImportExportWidget>
    with TickerProviderStateMixin {
  // Controladores de animación
  late TabController _tabController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // Estado de la importación
  bool _isImporting = false;
  bool _isExporting = false;
  ImportResult? _lastImportResult;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  // Opciones configurables
  ImportOptions _importOptions = const ImportOptions();
  ExportOptions _exportOptions = const ExportOptions();

  // Controladores de formulario
  final _dateFormatController = TextEditingController(text: 'yyyy-MM-dd');
  final _encodingController = TextEditingController(text: 'utf-8');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _initializeExportOptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _progressController.dispose();
    _dateFormatController.dispose();
    _encodingController.dispose();
    super.dispose();
  }

  void _initializeExportOptions() {
    // Campos disponibles para exportación
    const availableFields = [
      'id',
      'sku',
      'name',
      'description',
      'categoryName',
      'supplierName',
      'itemType',
      'unitOfMeasure',
      'brand',
      'model',
      'partNumber',
      'initialCost',
      'unitCost',
      'currentStock',
      'minimumStock',
      'maximumStock',
      'location',
      'shelf',
      'bin',
      'barcode',
      'qrCode',
      'isActive',
      'createdAt',
      'updatedAt',
    ];

    _exportOptions = ExportOptions(
      fields: availableFields,
      format: 'csv',
      includeHeaders: true,
    );
  }
  // === MÉTODOS DE IMPORTACIÓN ===

  // Selección de archivo para importación - CORREGIDO PARA WEB
  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'json'],
        allowMultiple: false,
        withData: true, // ✅ IMPORTANTE: para obtener bytes en web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes; // ✅ CAMBIO: usar bytes
        });

        // Analizar el archivo para mostrar preview
        if (_selectedFileBytes != null) {
          await _analyzeFileBytes(_selectedFileBytes!, file.extension ?? '');
        }
      }
    } catch (e) {
      _showErrorDialog('Error al seleccionar archivo', e.toString());
    }
  }

  // Analizar archivo seleccionado usando bytes - NUEVO MÉTODO
  Future<void> _analyzeFileBytes(Uint8List bytes, String extension) async {
    try {
      String content = '';

      switch (extension.toLowerCase()) {
        case 'csv':
          content = utf8.decode(bytes);
          break;
        case 'json':
          content = utf8.decode(bytes);
          break;
        case 'xlsx':
          content = 'Archivo Excel detectado - ${bytes.length} bytes';
          break;
        default:
          content = 'Archivo detectado - ${bytes.length} bytes';
      }

      // Mostrar preview del contenido
      if (content.isNotEmpty && mounted) {
        _showFilePreviewDialog(content, extension);
      }
    } catch (e) {
      debugPrint('Error analizando archivo: $e');
    }
  }

  // Mostrar diálogo de preview del archivo
  void _showFilePreviewDialog(String content, String extension) {
    final isTextFile = ['csv', 'json', 'txt'].contains(extension.toLowerCase());

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                          Icon(
                            isTextFile
                                ? PhosphorIcons.fileText()
                                : PhosphorIcons.table(),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Vista Previa ($extension)',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child:
                            isTextFile
                                ? SingleChildScrollView(
                                  child: Text(
                                    content.length > 2000
                                        ? '${content.substring(0, 2000)}\n... (truncado)'
                                        : content,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                                : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      PhosphorIcons.checkCircle(),
                                      size: 48,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      content,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Listo para importar',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _startImport();
                          },
                          icon: Icon(PhosphorIcons.downloadSimple()),
                          label: const Text('Importar Ahora'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  // Iniciar proceso de importación - CORREGIDO PARA USAR BYTES
  Future<void> _startImport() async {
    if (_selectedFileBytes == null || _selectedFileName == null) {
      _showErrorDialog('Error', 'Por favor selecciona un archivo primero');
      return;
    }

    setState(() {
      _isImporting = true;
      _lastImportResult = null;
    });

    _progressController.forward();

    try {
      // Llamar al servicio API con los bytes del archivo
      final response = await InventoryApiService.importInventoryFromFile(
        fileBytes: _selectedFileBytes!,
        fileName: _selectedFileName!,
        options: _importOptions,
      );

      if (response.success && response.data != null) {
        setState(() {
          _lastImportResult = response.data;
          _isImporting = false;
        });

        _progressController.reset();
        _showImportResultDialog(response.data!);

        // Limpiar archivo seleccionado
        setState(() {
          _selectedFileName = null;
          _selectedFileBytes = null;
        });

        // Llamar callback de actualización si existe
        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
      } else {
        throw Exception(
          response.message ?? 'Error desconocido en la importación',
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      _progressController.reset();
      _showErrorDialog('Error de Importación', e.toString());
    }
  }

  // === MÉTODOS DE EXPORTACIÓN ===
  Future<void> _startExport() async {
    if (widget.items.isEmpty) {
      _showErrorDialog('Error', 'No hay elementos para exportar');
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // Definir el orden canónico de las columnas
      const canonicalOrder = [
        'id',
        'sku',
        'name',
        'description',
        'categoryName',
        'supplierName',
        'itemType',
        'unitOfMeasure',
        'brand',
        'model',
        'partNumber',
        'initialCost',
        'unitCost',
        'currentStock',
        'minimumStock',
        'maximumStock',
        'location',
        'shelf',
        'bin',
        'barcode',
        'qrCode',
        'isActive',
        'createdAt',
        'updatedAt',
      ];

      // Ordenar los campos seleccionados según el orden canónico
      final sortedFields =
          canonicalOrder
              .where((field) => _exportOptions.fields.contains(field))
              .toList();

      final response = await InventoryApiService.exportInventoryToExcel(
        items: widget.items,
        selectedFields: sortedFields,
        includeHeaders: _exportOptions.includeHeaders,
      );

      if (response.success && response.data != null) {
        final bytes = response.data!;
        final fileName =
            'inventario_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        await dl.saveBytes(
          fileName,
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ?? 'Excel exportado exitosamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.message ?? 'Error al exportar');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Error de Exportación',
          'Error al exportar inventario: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  // === MÉTODOS DE DIÁLOGOS ===
  void _showImportResultDialog(ImportResult result) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Resultado de Importación'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total de registros: ${result.totalRecords}'),
                Text(
                  'Importados exitosamente: ${result.successfulImports}',
                  style: const TextStyle(color: Colors.green),
                ),
                Text(
                  'Omitidos: ${result.skippedRecords}',
                  style: const TextStyle(color: Colors.orange),
                ),
                Text(
                  'Errores: ${result.errorRecords}',
                  style: const TextStyle(color: Colors.red),
                ),
                Text(
                  'Tasa de éxito: ${(result.successRate * 100).toStringAsFixed(1)}%',
                ),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Errores:'),
                  ...result.errors
                      .take(3)
                      .map(
                        (error) => Text(
                          '• $error',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  if (result.errors.length > 3)
                    Text('... y ${result.errors.length - 3} más'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              if (widget.onRefresh != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onRefresh!();
                  },
                  child: const Text('Actualizar Lista'),
                ),
            ],
          ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  // === MÉTODO DE PLANTILLA ===
  Future<void> _downloadTemplate() async {
    try {
      final response = await InventoryApiService.downloadInventoryTemplate();

      if (response.success && response.data != null) {
        final bytes = response.data!;
        final fileName = 'plantilla_inventario.xlsx';

        await dl.saveBytes(
          fileName,
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ?? 'Plantilla descargada exitosamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.message ?? 'Error al descargar plantilla');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error', 'Error al descargar plantilla: $e');
      }
    }
  }

  // === INTERFAZ DE USUARIO ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar/Exportar Inventario'),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(PhosphorIcons.downloadSimple()), text: 'Importar'),
            Tab(icon: Icon(PhosphorIcons.uploadSimple()), text: 'Exportar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildImportTab(), _buildExportTab()],
      ),
    );
  }

  // Tab de importación
  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sección de Archivo y Plantilla (Fila en escritorio, Columna en móvil)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildFileSelectionCard()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildTemplateCard()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildFileSelectionCard(),
                        const SizedBox(height: 16),
                        _buildTemplateCard(),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 32),
              
              const Text(
                'Configuración',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 2. Opciones de Importación (Grid o Lista)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                     SwitchListTile(
                      title: const Text('Actualizar existentes'),
                      subtitle: const Text('Sobrescribir si SKU existe'),
                      secondary: Icon(PhosphorIcons.arrowsClockwise()),
                      value: _importOptions.updateExisting,
                      onChanged: (v) => setState(() => _importOptions = ImportOptions(
                        updateExisting: v,
                        createCategories: _importOptions.createCategories,
                        createSuppliers: _importOptions.createSuppliers,
                        dateFormat: _importOptions.dateFormat,
                        encoding: _importOptions.encoding,
                        skipFirstRow: _importOptions.skipFirstRow,
                      )),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Crear categorías'),
                      subtitle: const Text('Automático si no existe'),
                      secondary: Icon(PhosphorIcons.squaresFour()),
                      value: _importOptions.createCategories,
                      onChanged: (v) => setState(() => _importOptions = ImportOptions(
                        updateExisting: _importOptions.updateExisting,
                        createCategories: v,
                        createSuppliers: _importOptions.createSuppliers,
                        dateFormat: _importOptions.dateFormat,
                        encoding: _importOptions.encoding,
                        skipFirstRow: _importOptions.skipFirstRow,
                      )),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Crear proveedores'),
                      subtitle: const Text('Automático si no existe'),
                      secondary: Icon(PhosphorIcons.truck()),
                      value: _importOptions.createSuppliers,
                      onChanged: (v) => setState(() => _importOptions = ImportOptions(
                        updateExisting: _importOptions.updateExisting,
                        createCategories: _importOptions.createCategories,
                        createSuppliers: v,
                        dateFormat: _importOptions.dateFormat,
                        encoding: _importOptions.encoding,
                        skipFirstRow: _importOptions.skipFirstRow,
                      )),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Omitir encabezados'),
                      subtitle: const Text('Primera fila es título'),
                      secondary: Icon(PhosphorIcons.rows()),
                      value: _importOptions.skipFirstRow,
                      onChanged: (v) => setState(() => _importOptions = ImportOptions(
                        updateExisting: _importOptions.updateExisting,
                        createCategories: _importOptions.createCategories,
                        createSuppliers: _importOptions.createSuppliers,
                        dateFormat: _importOptions.dateFormat,
                        encoding: _importOptions.encoding,
                        skipFirstRow: v,
                      )),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 3. Botón de Acción Principal
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedFileBytes != null && !_isImporting
                          ? _startImport
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isImporting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 12),
                                Text('Procesando...', style: TextStyle(fontSize: 16)),
                              ],
                            )
                          : const Text('INICIAR IMPORTACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ),
              ),

              if (_lastImportResult != null) ...[
                const SizedBox(height: 32),
                _buildResultCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(PhosphorIcons.uploadSimple(), color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              const Text('1. Cargar Archivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _selectFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 1, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).primaryColor.withOpacity(0.02),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFileName != null ? PhosphorIcons.checkCircle() : PhosphorIcons.cloudArrowUp(),
                    size: 40,
                    color: _selectedFileName != null ? Colors.green : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName ?? 'Toca para seleccionar archivo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedFileName != null ? Colors.black87 : Colors.grey.shade600,
                      fontWeight: _selectedFileName != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (_selectedFileName == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('.csv, .xlsx, .json', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(PhosphorIcons.downloadSimple(), color: Colors.amber.shade700),
              ),
              const SizedBox(width: 12),
              const Text('2. Descargar Plantilla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Usa la plantilla oficial para evitar errores de formato al importar.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: Icon(PhosphorIcons.downloadSimple()),
              label: const Text('Descargar Excel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.amber.shade600),
                foregroundColor: Colors.amber.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Última Importación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    _lastImportResult!.totalRecords.toString(),
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Exitosos',
                    _lastImportResult!.successfulImports.toString(),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Errores',
                    _lastImportResult!.errorRecords.toString(),
                    Colors.red,
                  ),
                ),
              ],
            ),
            
            // Mostrar lista de errores si existen
            if (_lastImportResult!.errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(PhosphorIcons.warningCircle(), color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Detalle de Errores (${_lastImportResult!.errors.length})',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _lastImportResult!.errors.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              _lastImportResult!.errors[index],
                              style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tab de exportación
  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información de elementos
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Elementos a Exportar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('Total de elementos: ${widget.items.length}'),
                  Text('Categorías: ${widget.categories.length}'),
                  Text('Proveedores: ${widget.suppliers.length}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Opciones de exportación
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Opciones de Exportación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _exportOptions.format,
                    decoration: const InputDecoration(
                      labelText: 'Formato de archivo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'csv', child: Text('CSV')),
                      DropdownMenuItem(value: 'json', child: Text('JSON')),
                      DropdownMenuItem(
                        value: 'xlsx',
                        child: Text('Excel (CSV compatible)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _exportOptions = ExportOptions(
                            fields: _exportOptions.fields,
                            format: value,
                            dateFormat: _exportOptions.dateFormat,
                            includeHeaders: _exportOptions.includeHeaders,
                            encoding: _exportOptions.encoding,
                          );
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Incluir encabezados'),
                    subtitle: const Text('Primera fila con nombres de campos'),
                    value: _exportOptions.includeHeaders,
                    onChanged: (value) {
                      setState(() {
                        _exportOptions = ExportOptions(
                          fields: _exportOptions.fields,
                          format: _exportOptions.format,
                          dateFormat: _exportOptions.dateFormat,
                          includeHeaders: value,
                          encoding: _exportOptions.encoding,
                        );
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Campos a incluir:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children:
                        {
                              'id': 'ID',
                              'sku': 'SKU',
                              'name': 'Nombre',
                              'description': 'Descripción',
                              'categoryName': 'Categoría',
                              'supplierName': 'Proveedor',
                              'itemType': 'Tipo',
                              'unitOfMeasure': 'Unidad',
                              'brand': 'Marca',
                              'model': 'Modelo',
                              'initialCost': 'Costo Inicial',
                              'unitCost': 'Precio de Venta',
                              'currentStock': 'Stock Actual',
                              'minimumStock': 'Stock Mínimo',
                              'maximumStock': 'Stock Máximo',
                              'location': 'Ubicación',
                              'shelf': 'Estante',
                              'bin': 'Compartimiento',
                              'isActive': 'Activo',
                            }
                            .entries
                            .map(
                              (entry) => FilterChip(
                                label: Text(entry.value),
                                selected: _exportOptions.fields.contains(
                                  entry.key,
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    final newFields = List<String>.from(
                                      _exportOptions.fields,
                                    );
                                    if (selected) {
                                      newFields.add(entry.key);
                                    } else {
                                      newFields.remove(entry.key);
                                    }
                                    _exportOptions = ExportOptions(
                                      fields: newFields,
                                      format: _exportOptions.format,
                                      dateFormat: _exportOptions.dateFormat,
                                      includeHeaders:
                                          _exportOptions.includeHeaders,
                                      encoding: _exportOptions.encoding,
                                    );
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Botón de exportación
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  widget.items.isNotEmpty && !_isExporting
                      ? _startExport
                      : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child:
                  _isExporting
                      ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Exportando...'),
                        ],
                      )
                      : const Text(
                        'Iniciar Exportación',
                        style: TextStyle(fontSize: 16),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
