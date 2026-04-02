import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../controllers/geocercas_controller.dart';
import '../models/geocerca_model.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'geocercas_monitor_page.dart'; // ✅ NUEVO
import '../widgets/sync_indicator.dart'; // ✅ NUEVO

class GeocercasMapPage extends StatefulWidget {
  const GeocercasMapPage({super.key});

  @override
  State<GeocercasMapPage> createState() => _GeocercasMapPageState();
}

class _GeocercasMapPageState extends State<GeocercasMapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Posición inicial por defecto (Bogotá)
  static const LatLng _initialPosition = LatLng(4.6097, -74.0817);

  // Variables para la geocerca temporal (visualización previa)
  LatLng? _tempPosition;
  double _tempRadius = 100.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final controller = Provider.of<GeocercasController>(context, listen: false);
    await controller.cargarGeocercas();

    // En móvil: obtener ubicación GPS para centrar el mapa y monitorear
    // En web: no pedimos GPS — centramos en la primera geocerca directamente
    if (!kIsWeb) {
      try {
        await controller.obtenerUbicacionActual();
      } catch (_) {}
    }

    if (controller.currentPosition != null) {
      _moveCamera(
        LatLng(
          controller.currentPosition!.latitude,
          controller.currentPosition!.longitude,
        ),
      );
    } else if (controller.geocercas.isNotEmpty) {
      _moveCamera(
        LatLng(
          controller.geocercas.first.latitud,
          controller.geocercas.first.longitud,
        ),
      );
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    // Usar Uri.https para codificar correctamente los parámetros (espacios, #, etc.)
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'addressdetails': '1',
    });

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'InfoApp/1.0 (com.fercho.infoapp)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final point = LatLng(lat, lon);

          _mapController.move(point, 14); // Mover y hacer zoom

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ubicación encontrada: ${data[0]['display_name'].split(',')[0]}',
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se encontró la ubicación')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error buscando ubicación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al buscar ubicación')),
        );
      }
    }
  }

  void _moveCamera(LatLng target) {
    _mapController.move(target, 15);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // Si queremos crear con long press, usamos onLongPress en MapOptions
    // Si queremos con tap, usamos onTap.
    // El usuario mencionó "Mantén presionado", así que usaremos onLongPress.
  }

  void _onMapLongPress(TapPosition tapPosition, LatLng point) {
    // Verificar permiso de crear
    if (!PermissionStore.instance.can('geocercas', 'crear')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para crear geocercas'),
        ),
      );
      return;
    }
    
    setState(() {
      _tempPosition = point;
      _tempRadius = 100.0;
    });
    _showGeocercaDialog(newPosition: point).then((_) {
      // Limpiar visualización temporal al cerrar el diálogo
      if (mounted) {
        setState(() {
          _tempPosition = null;
        });
      }
    });
  }

  Future<void> _showOptionsDialog(Geocerca geo) async {
    final canUpdate = PermissionStore.instance.can('geocercas', 'actualizar');
    final canDelete = PermissionStore.instance.can('geocercas', 'eliminar');
    
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(geo.nombre),
            content: const Text('¿Qué deseas hacer con esta geocerca?'),
            actions: [
              if (canUpdate)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showGeocercaDialog(geocercaToEdit: geo);
                  },
                  child: const Text('Editar'),
                ),
              if (canDelete)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteDialog(geo);
                  },
                  child: const Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  Future<void> _showGeocercaDialog({
    LatLng? newPosition,
    Geocerca? geocercaToEdit,
  }) async {
    final isEditing = geocercaToEdit != null;
    final nombreCtrl = TextEditingController(
      text: geocercaToEdit?.nombre ?? '',
    );
    final latCtrl = TextEditingController(
      text:
          isEditing
              ? geocercaToEdit.latitud.toString()
              : (newPosition?.latitude.toStringAsFixed(5) ?? ''),
    );
    final lngCtrl = TextEditingController(
      text:
          isEditing
              ? geocercaToEdit.longitud.toString()
              : (newPosition?.longitude.toStringAsFixed(5) ?? ''),
    );
    final radioCtrl = TextEditingController(
      text: isEditing ? geocercaToEdit.radio.toString() : '100',
    );

    // Si estamos editando, mostrar el radio actual visualmente
    if (isEditing) {
      setState(() {
        _tempPosition = LatLng(
          geocercaToEdit.latitud,
          geocercaToEdit.longitud,
        );
        _tempRadius = geocercaToEdit.radio.toDouble();
      });
    }

    // Actualizar radio visualmente mientras se escribe
    radioCtrl.addListener(() {
      final val = double.tryParse(radioCtrl.text);
      if (val != null && mounted) {
        setState(() {
          _tempRadius = val;
        });
      }
    });

    // Actualizar posición visualmente si se cambian lat/lng manualmente
    void updateTempPosition() {
      final lat = double.tryParse(latCtrl.text);
      final lng = double.tryParse(lngCtrl.text);
      if (lat != null && lng != null && mounted) {
        setState(() {
          _tempPosition = LatLng(lat, lng);
        });
      }
    }

    latCtrl.addListener(updateTempPosition);
    lngCtrl.addListener(updateTempPosition);

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isEditing ? 'Editar Geocerca' : 'Nueva Geocerca'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del lugar',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Latitud',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.my_location, color: Colors.blue),
                        tooltip: 'Usar mi ubicación actual',
                        onPressed: () async {
                          final ctrl = Provider.of<GeocercasController>(
                            context,
                            listen: false,
                          );
                          // Forzar actualización de ubicación
                          try {
                            await ctrl.obtenerUbicacionActual();
                            if (ctrl.currentPosition != null && mounted) {
                              latCtrl.text =
                                  ctrl.currentPosition!.latitude.toString();
                              lngCtrl.text =
                                  ctrl.currentPosition!.longitude.toString();
                              // Disparar listeners manualmente si es necesario o dejar que el controller lo haga
                              // (Los listeners de los textfields actualizarán _tempPosition automáticamente)
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo obtener la ubicación',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lngCtrl,
                    decoration: const InputDecoration(labelText: 'Longitud'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: radioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Radio (metros)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nombreCtrl.text.isEmpty ||
                      radioCtrl.text.isEmpty ||
                      latCtrl.text.isEmpty ||
                      lngCtrl.text.isEmpty) {
                    return;
                  }

                  final lat = double.parse(latCtrl.text);
                  final lng = double.parse(lngCtrl.text);
                  final radio = int.parse(radioCtrl.text);

                  // Validación: Radio mínimo de 20 metros
                  if (radio < 20) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'El radio mínimo debe ser de 20 metros para asegurar la detección.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  final nombre = nombreCtrl.text;

                  final ctrl = Provider.of<GeocercasController>(
                    context,
                    listen: false,
                  );

                  bool success;
                  if (isEditing) {
                    final editada = Geocerca(
                      id: geocercaToEdit.id,
                      nombre: nombre,
                      latitud: lat,
                      longitud: lng,
                      radio: radio,
                      estado: geocercaToEdit.estado,
                    );
                    success = await ctrl.actualizarGeocerca(editada);
                  } else {
                    final nuevo = Geocerca(
                      id: 0,
                      nombre: nombre,
                      latitud: lat,
                      longitud: lng,
                      radio: radio,
                      estado: 1,
                    );
                    success = await ctrl.crearGeocerca(nuevo);
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? 'Geocerca actualizada'
                                : 'Geocerca creada',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    ).then((_) {
      // Limpiar visualización temporal al cerrar el diálogo
      if (mounted) {
        setState(() {
          _tempPosition = null;
        });
      }
    });
  }

  Future<void> _showDeleteDialog(Geocerca geo) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Eliminar ${geo.nombre}'),
            content: const Text('¿Estás seguro de eliminar esta geocerca?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  final ctrl = Provider.of<GeocercasController>(
                    context,
                    listen: false,
                  );
                  await ctrl.eliminarGeocerca(geo.id);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  bool _isDialogShowing = false;

  void _showEvidenceDialog(BuildContext context, PendingTransition transition) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          transition.event == GeofenceEvent.ingreso 
              ? 'Confirmar Entrada' 
              : 'Confirmar Salida'
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              transition.event == GeofenceEvent.ingreso 
                  ? Icons.login 
                  : Icons.logout,
              size: 48,
              color: transition.event == GeofenceEvent.ingreso ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Se ha detectado tu presencia en: ${transition.geocerca.nombre}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Es obligatorio capturar una fotografía como evidencia para proceder con el registro.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Tomar Fotografía'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandingService().primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final ImagePicker picker = ImagePicker();
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );

                if (photo != null && context.mounted) {
                  final controller = Provider.of<GeocercasController>(context, listen: false);
                  final success = await controller.confirmarTransicion(File(photo.path));
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    _isDialogShowing = false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success 
                              ? 'Registro confirmado exitosamente' 
                              : 'Error al procesar el registro'
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  void _showLargePhoto(String photoPath, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              backgroundColor: BrandingService().primaryColor,
              foregroundColor: Colors.white,
            ),
            Image.file(
              File(photoPath),
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = BrandingService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Geocercas (OpenStreetMap)'),
        backgroundColor: branding.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          const SyncIndicator(), // ✅ Indicador de sincronización en background
          if (PermissionStore.instance.can('geocercas', 'crear'))
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Crear Geocerca',
              onPressed: () => _showGeocercaDialog(),
            ),
          // ✅ Botón de Monitoreo en Tiempo Real
          if (PermissionStore.instance.can('geocerca', 'monitoreo'))
            IconButton(
              icon: const Icon(Icons.monitor),
              tooltip: 'Monitoreo en Tiempo Real',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GeocercasMonitorPage(),
                  ),
                );
              },
            ),
        ],
      ),
      body: Consumer<GeocercasController>(
        builder: (context, controller, child) {
          // Detectar transición pendiente y mostrar diálogo
          if (controller.pendingTransition != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showEvidenceDialog(context, controller.pendingTransition!);
            });
          }

          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Convertir geocercas a marcadores y círculos
          final markers =
              controller.geocercas.map((geo) {
                return Marker(
                  point: LatLng(geo.latitud, geo.longitud),
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () => _showOptionsDialog(geo),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          color: Colors.white,
                          child: Text(
                            geo.nombre,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList();

          final circles =
              controller.geocercas.map((geo) {
                return CircleMarker(
                  point: LatLng(geo.latitud, geo.longitud),
                  color: Colors.blue.withOpacity(0.2),
                  borderStrokeWidth: 2,
                  borderColor: Colors.blue,
                  useRadiusInMeter: true,
                  radius: geo.radio.toDouble(),
                );
              }).toList();

          // Agregar círculo temporal si existe
          if (_tempPosition != null) {
            circles.add(
              CircleMarker(
                point: _tempPosition!,
                color: Colors.green.withOpacity(0.3),
                borderStrokeWidth: 2,
                borderColor: Colors.green,
                useRadiusInMeter: true,
                radius: _tempRadius,
              ),
            );

            // Agregar marcador temporal también para que se vea el centro
            markers.add(
              Marker(
                point: _tempPosition!,
                width: 80,
                height: 80,
                child: const Column(
                  children: [
                    Icon(Icons.add_location, color: Colors.green, size: 40),
                    Text(
                      'Nueva',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialPosition,
                  initialZoom: 15, // Zoom inicial más cercano para ver mejor
                  onTap: _onMapTap, // Permitir crear con un simple click/tap
                  onLongPress: _onMapLongPress,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.novatechdevelopment.infoapp',
                  ),
                  CircleLayer(circles: circles),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Buscar ciudad o dirección...',
                              border: InputBorder.none,
                            ),
                            onSubmitted: _searchLocation,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed:
                              () => _searchLocation(_searchController.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.nameOfCurrentGeofence != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Mostrar la foto si existe una en la sesión actual
                            if (controller.sessionPhotos.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                   final photoPath = controller.sessionPhotos[controller.insideGeofences.first];
                                   if (photoPath != null) {
                                     _showLargePhoto(photoPath, 'Evidencia de Entrada');
                                   }
                                },
                                child: Container(
                                  width: 35,
                                  height: 35,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    image: DecorationImage(
                                      image: FileImage(File(controller.sessionPhotos[controller.insideGeofences.first]!)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              )
                            else 
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Estás en: ${controller.nameOfCurrentGeofence}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Card(
                      color: Colors.white.withOpacity(0.9),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          'Mantén presionado en el mapa para agregar una nueva geocerca.\nToca un marcador para editar o eliminar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
