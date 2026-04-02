import 'package:flutter/material.dart';
import 'package:infoapp/main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:file_picker/file_picker.dart';
import 'branding_service.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/features/env/pages/show_server_qr_page.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

class BrandingPage extends StatefulWidget {
  const BrandingPage({super.key});

  @override
  State<BrandingPage> createState() => _BrandingPageState();
}

class _BrandingPageState extends State<BrandingPage> {
  bool _isLoading = false;
  bool _isSaving = false;
  final BrandingService _brandingService = BrandingService();

  // Configuración actual
  Color _selectedColor = Colors.blue;
  String? _logoUrl;
  String? _logoBase64;
  String? _backgroundUrl;
  String? _backgroundBase64;
  bool _verTiempos = false;

  // Colores predefinidos
  final List<Color> _predefinedColors = [
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.yellow,
    Colors.lime,
    Colors.green,
    Colors.teal,
    Colors.cyan,
    Colors.brown,
    Colors.blueGrey,
    Colors.grey,
    const Color(0xFF1565C0), // Azul corporativo
    const Color(0xFF2E7D32), // Verde corporativo
    const Color(0xFF6A1B9A), // Morado corporativo
    const Color(0xFFD32F2F), // Rojo corporativo
    const Color(0xFF00695C), // Verde agua corporativo
    const Color(0xFF5D4037), // Marrón corporativo
    const Color(0xFF424242), // Gris oscuro
  ];

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService.getBearerToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': token,
      };

      final response = await http.get(
        Uri.parse(
          '${ServerConfig.instance.apiRoot()}/core/branding/obtener_branding.php',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final brandingData = data['branding'] ?? data;
          setState(() {
            // Cargar color
            if (brandingData['color'] != null) {
              String colorString = brandingData['color'].toString();
              // Limpiar cualquier prefijo
              colorString = colorString
                  .replaceAll('0x', '')
                  .replaceAll('#', '');
              // Asegurar que tenga 6 o 8 caracteres (si es 6, agregar FF para opacidad)
              if (colorString.length == 6) {
                colorString = 'ff$colorString';
              }
              try {
                _selectedColor = Color(int.parse(colorString, radix: 16));
              } catch (_) {}
            }
            // Cargar logo
            if (brandingData['logo_url'] != null) {
              _logoUrl = brandingData['logo_url'];
            }
            // Cargar imagen de fondo
            if (brandingData['background_url'] != null) {
              _backgroundUrl = brandingData['background_url'];
            }
            // Cargar visibilidad de tiempos
            if (brandingData['ver_tiempos'] != null) {
              _verTiempos =
                  brandingData['ver_tiempos'] == true ||
                  brandingData['ver_tiempos'] == 1 ||
                  brandingData['ver_tiempos'] == '1';
            }
          });
        }
      }
    } catch (e) {
      _mostrarError('Error al cargar la configuración: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _seleccionarLogo() async {
    // Permiso requerido: branding: actualizar
    final canActualizar = PermissionStore.instance.can(
      'branding',
      'actualizar',
    );
    if (!canActualizar) {
      _mostrarError('No tiene permiso para actualizar el branding.');
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes != null) {
          // Validar tamaño (max 2MB)
          if (bytes.length > 2 * 1024 * 1024) {
            _mostrarError('El archivo es muy grande. Máximo 2MB.');
            return;
          }

          // Validar tipo de archivo
          final allowedTypes = ['jpg', 'jpeg', 'png', 'svg'];
          final extension = file.extension?.toLowerCase();
          if (extension == null || !allowedTypes.contains(extension)) {
            _mostrarError('Formato no válido. Use JPG, PNG o SVG.');
            return;
          }

          setState(() {
            _logoBase64 = base64Encode(bytes);
          });

          MyApp.showSnackBar(
            'Logo cargado. Recuerde guardar los cambios.',
            backgroundColor: Colors.green,
          );
        }
      }
    } catch (e) {
      _mostrarError('Error al cargar el logo: $e');
    }
  }

  Future<void> _seleccionarFondo() async {
    // Permiso requerido: branding: actualizar
    final canActualizar = PermissionStore.instance.can(
      'branding',
      'actualizar',
    );
    if (!canActualizar) {
      _mostrarError('No tiene permiso para actualizar el branding.');
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        final file = result.files.single;
        final bytes = file.bytes;

        if (bytes == null) {
          _mostrarError('No se pudo leer el archivo seleccionado.');
          return;
        }

        // Verificar tamaño (máximo 2MB)
        if (bytes.length > 2 * 1024 * 1024) {
          _mostrarError(
            'La imagen es demasiado grande. El tamaño máximo permitido es 2MB.',
          );
          return;
        }

        // Convertir a base64
        final base64String = base64Encode(bytes);

        setState(() {
          _backgroundBase64 = base64String;
        });

        MyApp.showSnackBar(
          'Imagen de fondo cargada. Recuerde guardar los cambios.',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      _mostrarError('Error al cargar la imagen de fondo: $e');
    }
  }

  Future<void> _guardarConfiguracion() async {
    // Permiso requerido: branding: actualizar
    final canActualizar = PermissionStore.instance.can(
      'branding',
      'actualizar',
    );
    if (!canActualizar) {
      _mostrarError('No tiene permiso para guardar cambios de branding.');
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      final colorHex = _selectedColor.value.toRadixString(16).padLeft(8, '0');

      final Map<String, dynamic> data = {
        'color': colorHex,
        'ver_tiempos': _verTiempos ? 1 : 0,
      };

      if (_logoBase64 != null) {
        data['logo_base64'] = _logoBase64;
      }

      if (_backgroundBase64 != null) {
        data['background_base64'] = _backgroundBase64;
      }

      final token = await AuthService.getBearerToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': token,
      };

      final response = await http.post(
        Uri.parse(
          '${ServerConfig.instance.apiRoot()}/core/branding/guardar_branding.php',
        ),
        headers: headers,
        body: jsonEncode(data),
      );

      final result = jsonDecode(response.body);
      if (result['success']) {
        MyApp.showSnackBar(
          'Configuración guardada correctamente',
          backgroundColor: Colors.green,
        );

        // Recargar configuración para obtener la URL del logo
        await _cargarConfiguracion();

        // Mostrar diálogo informativo
        _actualizarTemaGlobal();
      } else {
        _mostrarError('Error: ${result['message']}');
      }
    } catch (e) {
      _mostrarError('Error al guardar la configuración: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _actualizarTemaGlobal() {
    // Mostrar diálogo informativo
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Configuración Guardada'),
            content: const Text(
              'Los cambios se han guardado exitosamente. '
              'Reinicia la aplicación para ver los cambios aplicados.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  void _mostrarError(String mensaje) {
    MyApp.showSnackBar(mensaje, backgroundColor: Colors.red);
  }

  void _mostrarMensaje(String mensaje) {
    MyApp.showSnackBar(mensaje, backgroundColor: Colors.green);
  }

  void _resetearConfiguracion() {
    // Permiso requerido: branding: actualizar
    final canActualizar = PermissionStore.instance.can(
      'branding',
      'actualizar',
    );
    if (!canActualizar) {
      _mostrarError('No tiene permiso para resetear el branding.');
      return;
    }
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Resetear Configuración'),
            content: const Text(
              '¿Está seguro que desea resetear la configuración de marca a los valores predeterminados?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    final token = await AuthService.getBearerToken();
                    final headers = {
                      'Content-Type': 'application/json',
                      if (token != null) 'Authorization': token,
                    };

                    // Realizar la petición HTTP para resetear la configuración
                    final response = await http.post(
                      Uri.parse(
                        '${ServerConfig.instance.apiRoot()}/core/branding/resetear_branding.php',
                      ),
                      headers: headers,
                    );

                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      if (data['success']) {
                        // Notificar al servicio de branding para que recargue
                        _brandingService.forceReload();

                        setState(() {
                          _selectedColor = Colors.blue;
                          _logoUrl = null;
                          _logoBase64 = null;
                          _backgroundUrl = null;
                          _backgroundBase64 = null;
                        });

                        _mostrarMensaje(
                          'Configuración reseteada correctamente',
                        );
                      } else {
                        _mostrarError(
                          'Error al resetear la configuración: ${data["message"]}',
                        );
                      }
                    } else {
                      _mostrarError(
                        'Error al resetear la configuración: Error de servidor',
                      );
                    }
                  } catch (e) {
                    _mostrarError('Error al resetear la configuración: $e');
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                child: const Text('Resetear'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Marca'),
        backgroundColor: _selectedColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                PermissionStore.instance.can('branding', 'ver')
                    ? _cargarConfiguracion
                    : null,
            tooltip: 'Recargar configuración',
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed:
                PermissionStore.instance.can('branding', 'actualizar')
                    ? _resetearConfiguracion
                    : null,
            tooltip: 'Resetear configuración',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed:
                PermissionStore.instance.can('branding', 'ver')
                    ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShowServerQrPage(),
                        ),
                      );
                    }
                    : null,
            tooltip: 'Compartir servidor (QR)',
          ),
        ],
      ),
      body:
          !PermissionStore.instance.can('branding', 'ver')
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No tienes permiso para ver la configuración de marca',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vista previa del tema
                    _buildVistaPrevia(),

                    const SizedBox(height: 30),

                    // Configuración de funcionalidades
                    _buildConfiguracionFuncionalidades(),

                    const SizedBox(height: 30),

                    // Selector de colores
                    _buildSelectorColores(),

                    const SizedBox(height: 30),

                    // Configuración del logo
                    _buildConfiguracionLogo(),

                    const SizedBox(height: 30),

                    // Configuración de la imagen de fondo
                    _buildConfiguracionFondo(),

                    const SizedBox(height: 40),

                    // Botones de acción
                    _buildBotonesAccion(),
                  ],
                ),
              ),
    );
  }

  Widget _buildVistaPrevia() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: _selectedColor),
                const SizedBox(width: 8),
                Text(
                  'Vista Previa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _selectedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Simulación de AppBar
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  // Logo en AppBar
                  if (_logoBase64 != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(_logoBase64!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  else if (_logoUrl != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          '${ServerConfig.instance.apiRoot()}/$_logoUrl',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.business,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business, color: Colors.white),
                    ),

                  const SizedBox(width: 12),
                  const Text(
                    'Mi Aplicación',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Simulación de botones
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Botón Primario'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _selectedColor),
                      foregroundColor: _selectedColor,
                    ),
                    child: const Text('Botón Secundario'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorColores() {
    final canActualizar = PermissionStore.instance.can(
      'branding',
      'actualizar',
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: _selectedColor),
                const SizedBox(width: 8),
                Text(
                  'Color del Tema',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _selectedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecciona el color principal de tu aplicación:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Grid de colores
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _predefinedColors.length,
              itemBuilder: (context, index) {
                final color = _predefinedColors[index];
                final isSelected = color.value == _selectedColor.value;

                return GestureDetector(
                  onTap:
                      canActualizar
                          ? () {
                            setState(() {
                              _selectedColor = color;
                            });
                          }
                          : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : Border.all(color: Colors.grey.shade300),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child:
                        isSelected
                            ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                            : null,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Información del color seleccionado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _selectedColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Color seleccionado: #${_selectedColor.value.toRadixString(16).toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _selectedColor,
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

  Widget _buildConfiguracionLogo() {
    final canActualizar = PermissionStore.instance.can(
      'branding',
      'actualizar',
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: _selectedColor),
                const SizedBox(width: 8),
                Text(
                  'Logo de la Empresa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _selectedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Sube el logo de tu empresa (JPG, PNG o SVG, máximo 2MB):',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Vista previa del logo actual
            if (_logoBase64 != null || _logoUrl != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Logo actual:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            _logoBase64 != null
                                ? Image.memory(
                                  base64Decode(_logoBase64!),
                                  fit: BoxFit.contain,
                                )
                                : Image.network(
                                  '${ServerConfig.instance.apiRoot()}/$_logoUrl',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 40,
                                    );
                                  },
                                ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay logo configurado',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Botones para el logo
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canActualizar ? _seleccionarLogo : null,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _logoBase64 != null || _logoUrl != null
                          ? 'Cambiar Logo'
                          : 'Subir Logo',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _selectedColor,
                      side: BorderSide(color: _selectedColor),
                    ),
                  ),
                ),
                if (_logoBase64 != null || _logoUrl != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          canActualizar
                              ? () {
                                setState(() {
                                  _logoBase64 = null;
                                  _logoUrl = null;
                                });
                              }
                              : null,
                      icon: const Icon(Icons.delete),
                      label: const Text('Quitar Logo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguracionFondo() {
    final canActualizar = PermissionStore.instance.can(
      'branding',
      'actualizar',
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wallpaper, color: _selectedColor),
                const SizedBox(width: 8),
                Text(
                  'Imagen de Fondo para Login',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _selectedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Sube una imagen para personalizar el fondo de la pantalla de login (JPG o PNG, máximo 2MB):',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Vista previa de la imagen de fondo actual
            if (_backgroundBase64 != null || _backgroundUrl != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Imagen de fondo actual:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            _backgroundBase64 != null
                                ? Image.memory(
                                  base64Decode(_backgroundBase64!),
                                  fit: BoxFit.cover,
                                )
                                : Image.network(
                                  '${ServerConfig.instance.apiRoot()}/$_backgroundUrl',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 40,
                                    );
                                  },
                                ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay imagen de fondo configurada',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Botones para la imagen de fondo
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canActualizar ? _seleccionarFondo : null,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _backgroundBase64 != null || _backgroundUrl != null
                          ? 'Cambiar Imagen'
                          : 'Subir Imagen',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _selectedColor,
                      side: BorderSide(color: _selectedColor),
                    ),
                  ),
                ),
                if (_backgroundBase64 != null || _backgroundUrl != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          canActualizar
                              ? () {
                                setState(() {
                                  _backgroundBase64 = null;
                                  _backgroundUrl = null;
                                });
                              }
                              : null,
                      icon: const Icon(Icons.delete),
                      label: const Text('Quitar Imagen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonesAccion() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed:
                _isSaving
                    ? null
                    : (PermissionStore.instance.can('branding', 'actualizar')
                        ? _guardarConfiguracion
                        : null),
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar Configuración'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Los cambios se aplicarán después de guardar y reiniciar la sesión.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildConfiguracionFuncionalidades() {
    final canActualizar = PermissionStore.instance.can(
      'branding',
      'actualizar',
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_applications, color: _selectedColor),
                const SizedBox(width: 8),
                Text(
                  'Funcionalidades',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _selectedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Mostrar Trazabilidad de Tiempos'),
              subtitle: const Text(
                'Habilita una pestaña adicional en la edición de servicios para ver el tiempo transcurrido en cada estado.',
              ),
              value: _verTiempos,
              activeThumbColor: _selectedColor,
              onChanged:
                  canActualizar
                      ? (value) {
                        setState(() {
                          _verTiempos = value;
                        });
                      }
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
