// lib/pages/geocercas/pages/geocercas_monitor_page.dart

import 'dart:async';
import 'dart:math'; // ✅ Para cos() y sin()
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../models/geocerca_con_personal_model.dart';
import '../models/personal_activo_model.dart';
import '../services/geocerca_service.dart';
import '../widgets/sync_indicator.dart'; // ✅ NUEVO

class GeocercasMonitorPage extends StatefulWidget {
  const GeocercasMonitorPage({super.key});

  @override
  State<GeocercasMonitorPage> createState() => _GeocercasMonitorPageState();
}

class _GeocercasMonitorPageState extends State<GeocercasMonitorPage> {
  List<GeocercaConPersonal> _geocercas = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  DateTime? _lastUpdate;
  String _filtro = 'todas'; // 'todas', 'activas', 'con_personal'
  
  int _totalGeocercas = 0;
  int _geocercasActivas = 0;
  int _totalPersonal = 0;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    // Auto-refresh cada 30 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cargarDatos();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final data = await GeocercaService.obtenerMonitoreoTiempoReal();
      
      if (mounted) {
        setState(() {
          _geocercas = (data['geocercas'] as List)
              .map((g) => GeocercaConPersonal.fromJson(g))
              .toList();
          
          final stats = data['estadisticas'];
          _totalGeocercas = stats['total_geocercas'] ?? 0;
          _geocercasActivas = stats['geocercas_activas'] ?? 0;
          _totalPersonal = stats['total_personal'] ?? 0;
          
          _lastUpdate = DateTime.now();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<GeocercaConPersonal> get _geocercasFiltradas {
    switch (_filtro) {
      case 'activas':
        return _geocercas.where((g) => g.activo).toList();
      case 'con_personal':
        return _geocercas.where((g) => g.tienePersonal).toList();
      default:
        return _geocercas;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo en Tiempo Real'),
        actions: [
          // Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: _filtro == 'todas',
              onSelected: (selected) {
                if (selected) setState(() => _filtro = 'todas');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ChoiceChip(
              label: const Text('Solo Activas'),
              selected: _filtro == 'activas',
              onSelected: (selected) {
                if (selected) setState(() => _filtro = 'activas');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ChoiceChip(
              label: const Text('Solo con Personal'),
              selected: _filtro == 'con_personal',
              onSelected: (selected) {
                if (selected) setState(() => _filtro = 'con_personal');
              },
            ),
          ),
          const SyncIndicator(), // ✅ Indicador de sincronización en background
          // Botón de refresh manual
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarDatos,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // Mapa (70%)
                    Expanded(
                      flex: 7,
                      child: _buildMapa(),
                    ),
                    // Panel lateral (30%)
                    Expanded(
                      flex: 3,
                      child: _buildPanelLateral(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMapa() {
    // Calcular centro del mapa (promedio de todas las geocercas)
    if (_geocercasFiltradas.isEmpty) {
      return const Center(
        child: Text('No hay geocercas para mostrar'),
      );
    }

    double latSum = 0;
    double lngSum = 0;
    for (var geo in _geocercasFiltradas) {
      latSum += geo.latitud;
      lngSum += geo.longitud;
    }
    final center = LatLng(
      latSum / _geocercasFiltradas.length,
      lngSum / _geocercasFiltradas.length,
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
        minZoom: 10.0,
        maxZoom: 18.0,
      ),
      children: [
        // Capa de mapa base (OpenStreetMap)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.novatechdevelopment.infoapp',
        ),
        
        // Círculos de geocercas
        CircleLayer(
          circles: _geocercasFiltradas.map((geo) {
            return CircleMarker(
              point: LatLng(geo.latitud, geo.longitud),
              radius: geo.radio,
              useRadiusInMeter: true,
              color: geo.tienePersonal
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              borderColor: geo.tienePersonal ? Colors.blue : Colors.grey,
              borderStrokeWidth: 2,
            );
          }).toList(),
        ),
        
        // Marcadores de usuarios activos
        MarkerLayer(
          markers: _buildUserMarkers(),
        ),
        
        // Marcadores de nombres de geocercas
        MarkerLayer(
          markers: _geocercasFiltradas.map((geo) {
            return Marker(
              point: LatLng(geo.latitud, geo.longitud),
              width: 120,
              height: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  geo.nombre,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Marker> _buildUserMarkers() {
    List<Marker> markers = [];
    
    for (var geo in _geocercasFiltradas) {
      if (!geo.tienePersonal) continue;
      
      // Distribuir usuarios en círculo alrededor del centro de la geocerca
      int count = geo.personalActivo.length;
      for (int i = 0; i < count; i++) {
        final persona = geo.personalActivo[i];
        
        // Calcular posición en círculo (radio más pequeño para que estén dentro)
        double angle = (2 * 3.14159 * i) / count;
        double offsetLat = (geo.radio * 0.6 / 111320) * cos(angle);
        double offsetLng = (geo.radio * 0.6 / (111320 * cos(geo.latitud * 3.14159 / 180))) * sin(angle);
        
        markers.add(
          Marker(
            point: LatLng(geo.latitud + offsetLat, geo.longitud + offsetLng),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                // Mostrar info del usuario
                _mostrarInfoUsuario(persona, geo);
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    persona.nombre.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return markers;
  }

  void _mostrarInfoUsuario(PersonalActivo persona, GeocercaConPersonal geo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(persona.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Ubicación: ${geo.nombre}')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text('Entrada: ${DateFormat('HH:mm').format(persona.fechaIngreso)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer, size: 20),
                const SizedBox(width: 8),
                Text('Tiempo dentro: ${persona.tiempoDentro}'),
              ],
            ),
            if (persona.fotoIngreso != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Mostrar foto
                  Navigator.pop(context);
                  _mostrarFoto(persona.fotoIngreso!);
                },
                icon: const Icon(Icons.photo),
                label: const Text('Ver Foto de Entrada'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarFoto(String fotoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Evidencia Fotográfica'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  ServerConfig.instance.baseUrlFor(fotoUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelLateral() {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monitoreo en Tiempo Real',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_lastUpdate != null)
                  Text(
                    'Última actualización: ${DateFormat('HH:mm:ss').format(_lastUpdate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 16),
                // Estadísticas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Total Personal', _totalPersonal.toString()),
                    _buildStat('Activos', _geocercasActivas.toString()),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de personal activo
          Expanded(
            child: _buildListaPersonal(),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildListaPersonal() {
    // Aplanar lista de personal de todas las geocercas
    List<MapEntry<GeocercaConPersonal, PersonalActivo>> personalConGeo = [];
    
    for (var geo in _geocercasFiltradas) {
      for (var persona in geo.personalActivo) {
        personalConGeo.add(MapEntry(geo, persona));
      }
    }

    if (personalConGeo.isEmpty) {
      return const Center(
        child: Text('No hay personal activo en este momento'),
      );
    }

    return ListView.builder(
      itemCount: personalConGeo.length,
      itemBuilder: (context, index) {
        final entry = personalConGeo[index];
        final geo = entry.key;
        final persona = entry.value;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(
                persona.nombre.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(persona.nombre),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Ubicación: ${geo.nombre}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Entrada: ${DateFormat('HH:mm').format(persona.fechaIngreso)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Tiempo dentro: ${persona.tiempoDentro}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: persona.fotoIngreso != null
                ? IconButton(
                    icon: const Icon(Icons.photo_camera, color: Colors.orange),
                    onPressed: () => _mostrarFoto(persona.fotoIngreso!),
                    tooltip: 'Ver foto',
                  )
                : const Icon(Icons.photo_camera_outlined, color: Colors.grey),
          ),
        );
      },
    );
  }
}
