import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import '../../services/servicios_api_service.dart';
import '../../models/campo_adicional_model.dart';
import '../../services/download_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

/// Widget para manejar campos adicionales dinámicos específicos para servicios
class CamposAdicionalesServicios extends StatefulWidget {
  final int? servicioId;
  final int estadoId;
  final Map<int, dynamic> valoresCampos;
  final Function(Map<int, dynamic>) onValoresChanged;
  final bool enabled;
  final bool loadValuesOnInit;
  final String modulo;
  // ? NUEVO: Notificar al padre cuando los campos terminen de cargar
  final VoidCallback? onLoaded;

  const CamposAdicionalesServicios({
    super.key,
    this.servicioId,
    required this.estadoId,
    required this.valoresCampos,
    required this.onValoresChanged,
    this.enabled = true,
    this.loadValuesOnInit = false,
    this.modulo = 'Servicios',
    this.onLoaded,
  });

  @override
  CamposAdicionalesServiciosState createState() =>
      CamposAdicionalesServiciosState();
}

class CamposAdicionalesServiciosState
    extends State<CamposAdicionalesServicios> {
  List<Map<String, dynamic>> _camposAdicionales = [];
  bool _isLoading = false;
  bool _isUploadingFile = false;
  String? _authToken;

  // ? Exponer estado de carga para validaciones externas
  bool get estaCargando => _isLoading;

  @override
  void initState() {
    super.initState();
    _loadToken(); // Always load token

    _inicializarCampos();
  }

  Future<void> _inicializarCampos() async {
    // 🚀 OPTIMIZACIÓN: Intentar carga síncrona desde caché primero
    final cachedCampos = ServiciosApiService.obtenerCamposDesdeCache(
      estadoId: widget.estadoId,
      modulo: widget.modulo,
    );

    if (cachedCampos != null && cachedCampos.isNotEmpty) {
      // Si hay caché, inicializar inmediatamente sin loading visual
      final campos = cachedCampos
          .map(
            (campo) => {
              'id': campo.id,
              'nombre_campo': campo.nombreCampo,
              'tipo_campo': campo.tipoCampo,
              'obligatorio': campo.obligatorio ? 1 : 0,
              'estado_mostrar': campo.estadoMostrar,
            },
          )
          .toList();
      
      if (mounted) {
        setState(() {
          _camposAdicionales = campos;
        });
      }

      // Asegurar valores iniciales
      for (var campo in _camposAdicionales) {
        final campoId = int.tryParse(campo['id'].toString());
        if (campoId != null && !widget.valoresCampos.containsKey(campoId)) {
          widget.valoresCampos[campoId] = null;
        }
      }

      // Cargar valores (esto s puede requerir async)
      if (widget.servicioId != null && widget.loadValuesOnInit) {
         await _cargarValoresExistentes();
      }

      // Notificar carga lista SOLO después de cargar todo
      if (mounted) {
        widget.onLoaded?.call();
      }

    } else {
      // Si no hay caché, flujo normal con loading
      await _cargarCamposAdicionales();
    }
  }

  Future<void> _loadToken() async {
    final token = await AuthService.getBearerToken();
    if (mounted) {
      setState(() => _authToken = token);
    }
  }

  @override
  void didUpdateWidget(covariant CamposAdicionalesServicios oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recargar campos si cambia el estado, el módulo o el id del servicio
    if (oldWidget.estadoId != widget.estadoId ||
        oldWidget.modulo != widget.modulo ||
        oldWidget.servicioId != widget.servicioId) {
      _cargarCamposAdicionales();
    }
  }

  Future<void> _cargarCamposAdicionales() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 🚀 OPTIMIZACIÓN: Cargar campos y valores en paralelo
      List<CampoAdicionalModel> camposModelos = [];
      
      // Preparar tareas paralelas
      final tareas = <Future>[];
      
      // Tarea 1: Cargar campos
      final tareaCargarCampos = _cargarCamposDelEstado();
      tareas.add(tareaCargarCampos);
      
      // Tarea 2: Cargar valores (solo si aplica)
      if (widget.servicioId != null && widget.loadValuesOnInit) {
        tareas.add(_cargarValoresExistentes());
      }
      
      // ? Ejecutar en paralelo
      final resultados = await Future.wait(tareas);
      camposModelos = resultados[0] as List<CampoAdicionalModel>;

      // Convertir CampoAdicionalModel a Map<String, dynamic> para compatibilidad
      final campos =
          camposModelos
              .map(
                (campo) => {
                  'id': campo.id,
                  'nombre_campo': campo.nombreCampo,
                  'tipo_campo': campo.tipoCampo,
                  'obligatorio': campo.obligatorio ? 1 : 0,
                  'estado_mostrar': campo.estadoMostrar,
                },
              )
              .toList();
      
      if (mounted) {
        setState(() {
          _camposAdicionales = campos;
        });
      }

      // Inicializar valores vacíos si no existen
      for (var campo in _camposAdicionales) {
        final campoId = int.tryParse(campo['id'].toString());
        if (campoId != null && !widget.valoresCampos.containsKey(campoId)) {
          widget.valoresCampos[campoId] = null;
        }
      }
    } catch (e) {
      //       print('? Error cargando campos adicionales: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Avisar que la sección terminó de cargar (incluye valores existentes)
      try {
        widget.onLoaded?.call();
      } catch (_) {}
    }
  }

  /// ✨ NUEVO: Método separado para cargar campos del estado
  Future<List<CampoAdicionalModel>> _cargarCamposDelEstado() async {
    // Intento principal con el módulo recibido
    List<CampoAdicionalModel> camposModelos =
        await ServiciosApiService.obtenerCamposPorEstado(
          estadoId: widget.estadoId,
          modulo: widget.modulo,
        );

    // 🤖 Fallback inteligente: probar variantes de nombre de módulo
    if (camposModelos.isEmpty) {
      final modulo = widget.modulo;
      final lower = modulo.toLowerCase();
      final variantes = <String>{modulo};
      if (lower.startsWith('equ')) {
        variantes.addAll({'Equipo', 'equipo', 'Equipos'});
      } else if (lower.startsWith('serv')) {
        variantes.addAll({'Servicio', 'servicio', 'Servicios'});
      }

      for (final v in variantes) {
        if (v == modulo) continue;
        final resultado = await ServiciosApiService.obtenerCamposPorEstado(
          estadoId: widget.estadoId,
          modulo: v,
        );
        if (resultado.isNotEmpty) {
          camposModelos = resultado;
          break;
        }
      }
    }

    return camposModelos;
  }

  Future<void> _cargarValoresExistentes() async {
    if (widget.servicioId == null) return;

    try {
      // ? Usar el service - TODO el procesamiento se hace en el service!
      final valores = await ServiciosApiService.obtenerValoresCamposHibrido(
        servicioId: widget.servicioId!,
        modulo: widget.modulo,
      );

      // ? Simplemente agregar los valores obtenidos
      final nuevosValores = Map<int, dynamic>.from(widget.valoresCampos);
      nuevosValores.addAll(valores);
      widget.onValoresChanged(nuevosValores);
    } catch (e) {
      //       print('? Error cargando valores existentes: $e');
    }
  }

  void _actualizarValor(int campoId, dynamic valor) {
    final nuevosValores = Map<int, dynamic>.from(widget.valoresCampos);
    nuevosValores[campoId] = valor;
    widget.onValoresChanged(nuevosValores);
  }

  Widget _buildCampoSegunTipo(Map<String, dynamic> campo) {
    final campoId = int.tryParse(campo['id'].toString()) ?? 0;
    final tipoCampoRaw = campo['tipo_campo']?.toString() ?? '';
    final tipoCampo = tipoCampoRaw.toLowerCase();
    final obligatorio = campo['obligatorio'] == 1;

    switch (tipoCampo) {
      case 'texto':
        return _buildCampoTexto(campoId, obligatorio);

      case 'párrafo':
        return _buildCampoParrafo(campoId, obligatorio);

      case 'fecha':
        return _buildCampoFecha(campoId, obligatorio);

      case 'hora':
        return _buildCampoHora(campoId, obligatorio);

      case 'fecha y hora':
      case 'datetime':
      case 'datetimefield':
      case 'date-time':
      case 'date_time':
      case 'dateTime':
        return _buildCampoFechaHora(campoId, obligatorio);

      case 'entero':
        return _buildCampoEntero(campoId, obligatorio);

      case 'decimal':
        return _buildCampoDecimal(campoId, obligatorio);

      case 'moneda':
        return _buildCampoMoneda(campoId, obligatorio);

      case 'link':
        return _buildCampoLink(campoId, obligatorio);

      case 'imagen':
        return _buildCampoImagen(campoId, obligatorio);

      case 'archivo':
        return _buildCampoArchivo(campoId, obligatorio);

      default:
        return _buildCampoTexto(campoId, obligatorio);
    }
  }

  Widget _buildCampoTexto(int campoId, bool obligatorio) {
    return TextFormField(
      initialValue: widget.valoresCampos[campoId]?.toString(),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: 'Ingresa el texto',
        prefixIcon: const Icon(Icons.text_fields),
      ),
      enabled: widget.enabled,
      onChanged: (value) => _actualizarValor(campoId, value),
      validator:
          obligatorio
              ? (value) =>
                  (value == null || value.isEmpty)
                      ? 'Este campo es obligatorio'
                      : null
              : null,
    );
  }

  Widget _buildCampoParrafo(int campoId, bool obligatorio) {
    return TextFormField(
      initialValue: widget.valoresCampos[campoId]?.toString(),
      maxLines: 4,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: 'Ingresa el texto largo',
        prefixIcon: const Icon(Icons.text_snippet),
        alignLabelWithHint: true,
      ),
      enabled: widget.enabled,
      onChanged: (value) => _actualizarValor(campoId, value),
      validator:
          obligatorio
              ? (value) =>
                  (value == null || value.isEmpty)
                      ? 'Este campo es obligatorio'
                      : null
              : null,
    );
  }

  Widget _buildCampoFecha(int campoId, bool obligatorio) {
    final valor = widget.valoresCampos[campoId];

    return InkWell(
      onTap: widget.enabled ? () => _seleccionarFecha(campoId) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                valor != null ? _formatearFecha(valor) : 'Seleccionar fecha',
                style: TextStyle(
                  fontSize: 16,
                  color: valor != null ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoHora(int campoId, bool obligatorio) {
    final valor = widget.valoresCampos[campoId];

    return InkWell(
      onTap: widget.enabled ? () => _seleccionarHora(campoId) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                valor != null ? _formatearHora(valor) : 'Seleccionar hora',
                style: TextStyle(
                  fontSize: 16,
                  color: valor != null ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoFechaHora(int campoId, bool obligatorio) {
    final valor = widget.valoresCampos[campoId];
    DateTime? fechaHora;
    if (valor is DateTime) {
      fechaHora = valor;
    } else if (valor is String && valor.trim().isNotEmpty) {
      try {
        fechaHora = DateTime.parse(valor);
      } catch (_) {
        fechaHora = null;
      }
    }

    final fechaTexto =
        fechaHora != null ? _formatearFecha(fechaHora) : 'Seleccionar fecha';
    final horaTexto =
        fechaHora != null
            ? '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}'
            : 'Seleccionar hora';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap:
                    widget.enabled
                        ? () => _seleccionarFechaHora_fecha(campoId, fechaHora)
                        : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fechaTexto,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                fechaHora != null
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap:
                    widget.enabled
                        ? () => _seleccionarFechaHora_hora(campoId, fechaHora)
                        : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          horaTexto,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                fechaHora != null
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (obligatorio && fechaHora == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Este campo es obligatorio',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _seleccionarFechaHora_fecha(
    int campoId,
    DateTime? actual,
  ) async {
    final DateTime initialDate = actual ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final DateTime combinado = DateTime(
        picked.year,
        picked.month,
        picked.day,
        actual?.hour ?? TimeOfDay.now().hour,
        actual?.minute ?? TimeOfDay.now().minute,
      );
      _actualizarValor(campoId, combinado);
    }
  }

  Future<void> _seleccionarFechaHora_hora(int campoId, DateTime? actual) async {
    final TimeOfDay initialTime =
        actual != null
            ? TimeOfDay(hour: actual.hour, minute: actual.minute)
            : TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      final DateTime base = actual ?? DateTime.now();
      final DateTime combinado = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      _actualizarValor(campoId, combinado);
    }
  }

  Widget _buildCampoEntero(int campoId, bool obligatorio) {
    return TextFormField(
      initialValue: widget.valoresCampos[campoId]?.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: 'Ingresa un número entero',
        prefixIcon: const Icon(Icons.numbers),
      ),
      enabled: widget.enabled,
      onChanged: (value) {
        final intValue = int.tryParse(value);
        _actualizarValor(campoId, intValue);
      },
      validator: (value) {
        if (obligatorio && (value == null || value.isEmpty)) {
          return 'Este campo es obligatorio';
        }
        if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
          return 'Debe ser un número entero válido';
        }
        return null;
      },
    );
  }

  // Métodos auxiliares básicos
  Future<void> _seleccionarFecha(int campoId) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _actualizarValor(campoId, picked);
    }
  }

  Future<void> _seleccionarHora(int campoId) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final horaString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _actualizarValor(campoId, horaString);
    }
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  String _formatearHora(dynamic hora) {
    if (hora == null) return 'Sin hora';
    return hora.toString();
  }

  Widget _buildCampoDecimal(int campoId, bool obligatorio) {
    return TextFormField(
      initialValue: widget.valoresCampos[campoId]?.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: 'Ingresa un número decimal (ej: 123.45)',
        prefixIcon: const Icon(Icons.calculate),
      ),
      enabled: widget.enabled,
      onChanged: (value) {
        if (value.isEmpty) {
          _actualizarValor(campoId, null);
        } else {
          final doubleValue = double.tryParse(value);
          _actualizarValor(campoId, doubleValue);
        }
      },
      validator: (value) {
        if (obligatorio && (value == null || value.trim().isEmpty)) {
          return 'Este campo es obligatorio';
        }
        if (value != null && value.trim().isNotEmpty) {
          if (double.tryParse(value.trim()) == null) {
            return 'Debe ser un número decimal válido';
          }
        }
        return null;
      },
    );
  }

  Widget _buildCampoMoneda(int campoId, bool obligatorio) {
    return TextFormField(
      initialValue: widget.valoresCampos[campoId]?.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: 'Ingresa el monto (ej: 1500.50)',
        prefixText: '\$ ',
        prefixIcon: const Icon(Icons.attach_money),
        suffixText: 'COP',
      ),
      enabled: widget.enabled,
      onChanged: (value) {
        if (value.isEmpty) {
          _actualizarValor(campoId, null);
        } else {
          final doubleValue = double.tryParse(value);
          _actualizarValor(campoId, doubleValue);
        }
      },
      validator: (value) {
        if (obligatorio && (value == null || value.trim().isEmpty)) {
          return 'Este campo es obligatorio';
        }
        if (value != null && value.trim().isNotEmpty) {
          final doubleValue = double.tryParse(value.trim());
          if (doubleValue == null) {
            return 'Debe ser un monto válido';
          }
          if (doubleValue < 0) {
            return 'El monto no puede ser negativo';
          }
        }
        return null;
      },
    );
  }

  Widget _buildCampoLink(int campoId, bool obligatorio) {
    return TextFormField(
      initialValue: widget.valoresCampos[campoId]?.toString(),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: 'https://ejemplo.com',
        prefixIcon: const Icon(Icons.link),
      ),
      enabled: widget.enabled,
      onChanged: (value) => _actualizarValor(campoId, value),
      validator: (value) {
        if (obligatorio && (value == null || value.isEmpty)) {
          return 'Este campo es obligatorio';
        }
        if (value != null && value.isNotEmpty) {
          try {
            final uri = Uri.parse(value);
            if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
              return 'Ingresa una URL válida (debe empezar con http:// o https://)';
            }
          } catch (e) {
            return 'Ingresa una URL válida';
          }
        }
        return null;
      },
    );
  }

  Widget _buildCampoImagen(int campoId, bool obligatorio) {
    final imagenSeleccionada = widget.valoresCampos[campoId];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.image, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  imagenSeleccionada != null
                      ? 'Imagen: ${imagenSeleccionada['nombre_original'] ?? imagenSeleccionada['nombre'] ?? 'imagen.jpg'}'
                      : 'Seleccionar imagen',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        imagenSeleccionada != null
                            ? Colors.black87
                            : Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(
                  PhosphorIcons.uploadSimple(),
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                label: Text(imagenSeleccionada != null ? 'Cambiar' : 'Subir'),
                onPressed:
                    widget.enabled && !_isUploadingFile
                        ? () => _seleccionarImagen(campoId)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),

          if (imagenSeleccionada != null) ...[
            const SizedBox(height: 12),
            _buildPreviewImagen(imagenSeleccionada, campoId),
          ],

          if (obligatorio && imagenSeleccionada == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Este campo es obligatorio',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCampoArchivo(int campoId, bool obligatorio) {
    final archivoSeleccionado = widget.valoresCampos[campoId];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.paperclip(), color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  archivoSeleccionado != null
                      ? 'Archivo: ${archivoSeleccionado['nombre_original'] ?? archivoSeleccionado['nombre'] ?? 'archivo'}'
                      : 'Seleccionar archivo',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        archivoSeleccionado != null
                            ? Colors.black87
                            : Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(
                  PhosphorIcons.uploadSimple(),
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                label: Text(archivoSeleccionado != null ? 'Cambiar' : 'Subir'),
                onPressed:
                    widget.enabled && !_isUploadingFile
                        ? () => _seleccionarArchivo(campoId)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),

          if (archivoSeleccionado != null) ...[
            const SizedBox(height: 12),
            _buildPreviewArchivo(archivoSeleccionado),
          ],

          if (obligatorio && archivoSeleccionado == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Este campo es obligatorio',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewArchivo(Map<String, dynamic> archivo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.fileText(), size: 32, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  archivo['nombre_original'] ?? archivo['nombre'] ?? 'Archivo',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (archivo['size'] != null)
                  Text(
                    _formatBytes(archivo['size']),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (archivo['es_existente'] == true)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.blue),
              tooltip: 'Descargar',
              onPressed: () => _descargarArchivo(archivo),
            ),
        ],
      ),
    );
  }

  String _formatBytes(dynamic size) {
    final int bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  Widget _buildPreviewImagen(Map<String, dynamic> imagen, int campoId) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          // ? HACER CLICKEABLE PARA AMPLIAR
          GestureDetector(
            onTap: () => _ampliarImagen(imagen),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  imagen['es_existente'] == true
                      ? Image.network(
                        _construirUrlArchivo(imagen),
                        headers:
                            _authToken != null
                                ? {'Authorization': _authToken!}
                                : null,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildErrorContainer();
                        },
                      )
                      : imagen['preview'] != null
                      ? Image.memory(
                        imagen['preview'],
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                      )
                      : _buildPlaceholderContainer(),
            ),
          ),

          // 🛠️ BOTONES DE ACCIÓN
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón descargar
                GestureDetector(
                  onTap: () => _descargarArchivo(imagen),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.download,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Botón eliminar
                GestureDetector(
                  onTap: () => _actualizarValor(campoId, null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ? INDICADOR DE CLICKEABLE
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 12),
                  SizedBox(width: 2),
                  Text(
                    'Toca para ampliar',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  // Métodos auxiliares para archivos e imágenes
  Future<void> _seleccionarImagen(int campoId) async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Seleccionar Imagen'),
            content: const Text('¿Cómo quieres obtener la imagen?'),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Galería'),
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
              ),
              TextButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Cámara'),
                onPressed: () => Navigator.pop(context, ImageSource.camera),
              ),
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );

    if (source != null) {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (widget.servicioId != null) {
          // ? Si hay servicioId, subir al servidor
          await _subirImagenAlServidor(campoId, image);
        } else {
          // ? Si no hay servicioId, solo preview local
          final bytes = await image.readAsBytes();
          _actualizarValor(campoId, {
            'tipo': 'imagen',
            'nombre': image.name,
            'nombre_original': image.name,
            'preview': bytes,
            'es_existente': false,
            'extension': image.name.split('.').last.toLowerCase(),
          });
        }
      }
    }
  }

  Future<void> _seleccionarArchivo(int campoId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'txt',
        'ppt',
        'pptx',
        'csv',
      ],
      allowMultiple: false,
    );

    if (result != null) {
      PlatformFile file = result.files.first;

      // Validar tamaño del archivo (máximo 10MB)
      if (file.size > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El archivo es demasiado grande. Máximo 10MB.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (widget.servicioId != null) {
        // ? Si hay servicioId, subir al servidor
        await _subirArchivoAlServidor(campoId, file);
      } else {
        // ? Si no hay servicioId, solo guardar info local
        _actualizarValor(campoId, {
          'tipo': 'archivo',
          'nombre': file.name,
          'nombre_original': file.name,
          'extension': file.extension,
          'es_existente': false,
          'size': file.size,
        });
      }
    }
  }

  /// ? SUBIR IMAGEN AL SERVIDOR
  Future<void> _subirImagenAlServidor(int campoId, XFile image) async {
    if (widget.servicioId == null) return;

    setState(() => _isUploadingFile = true);

    try {
      final resultado = await ServiciosApiService.subirArchivoCampoAdicional(
        servicioId: widget.servicioId!,
        campoId: campoId,
        archivo: image,
        tipoCampo: 'Imagen',
      );

      if (resultado.isSuccess) {
        _actualizarValor(campoId, resultado.data);
        _mostrarMensaje('Imagen subida exitosamente', true);
      } else {
        _mostrarMensaje(resultado.error ?? 'Error subiendo imagen', false);
      }
    } catch (e) {
      _mostrarMensaje('Error: $e', false);
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  /// ? SUBIR ARCHIVO AL SERVIDOR
  Future<void> _subirArchivoAlServidor(int campoId, PlatformFile file) async {
    if (widget.servicioId == null) return;

    setState(() => _isUploadingFile = true);

    try {
      final resultado = await ServiciosApiService.subirArchivoPlatformFile(
        servicioId: widget.servicioId!,
        campoId: campoId,
        archivo: file,
      );

      if (resultado.isSuccess) {
        _actualizarValor(campoId, resultado.data);
        _mostrarMensaje('Archivo subido exitosamente', true);
      } else {
        _mostrarMensaje(resultado.error ?? 'Error subiendo archivo', false);
      }
    } catch (e) {
      _mostrarMensaje('Error: $e', false);
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  /// ? MOSTRAR MENSAJES AL USUARIO
  void _mostrarMensaje(String mensaje, bool esExito) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                esExito ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje)),
            ],
          ),
          backgroundColor:
              esExito ? Colors.green.shade600 : Colors.red.shade600,
          duration: Duration(seconds: esExito ? 3 : 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  /// ? NUEVO: Ampliar imagen en modal
  void _ampliarImagen(Map<String, dynamic> imagen) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            imagen['nombre_original'] ?? 'Imagen',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Imagen ampliada
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child:
                          imagen['es_existente'] == true
                              ? Image.network(
                                _construirUrlArchivo(imagen),
                                headers:
                                    _authToken != null
                                        ? {'Authorization': _authToken!}
                                        : null,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Error cargando imagen',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                              : imagen['preview'] != null
                              ? Image.memory(
                                imagen['preview'],
                                fit: BoxFit.contain,
                              )
                              : Container(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Vista previa no disponible',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  ),

                  // Botones de acción
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _descargarArchivo(imagen),
                            icon: const Icon(Icons.download),
                            label: const Text('Descargar'),
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
          ),
    );
  }

  /// 🚀 MÉTODO ACTUALIZADO: Descargar archivo/imagen directamente
  void _descargarArchivo(Map<String, dynamic> archivo) {
    try {
      //       print('?? Iniciando descarga directa...');
      //       print('?? Datos archivo: $archivo');

      // ? USAR EL NUEVO SERVICIO DE DESCARGA
      DownloadService.descargarCampoAdicional(
        datosArchivo: archivo,
        onSuccess: (mensaje) {
          _mostrarMensaje('? $mensaje', true);
        },
        onError: (error) {
          _mostrarMensaje('? $error', false);

          // ? FALLBACK: Abrir en nueva pestaa si falla la descarga
          if (kIsWeb) {
            final rutaPublica =
                archivo['ruta_publica'] ?? archivo['url_completa'];
            if (rutaPublica != null) {
              DownloadService.abrirArchivoEnNuevaPestana(rutaPublica);
              _mostrarMensaje('✅ Archivo abierto en nueva pestaña', true);
            }
          }
        },
      );
    } catch (e) {
      _mostrarMensaje('? Error al preparar descarga: $e', false);
    }
  }

  /// 📦 MÉTODO PÚBLICO PARA GUARDAR CAMPOS ADICIONALES
  Future<bool> guardarCamposAdicionales() async {
    if (_camposAdicionales.isEmpty || widget.servicioId == null) {
      return true; // No hay campos para guardar
    }

    try {
      // Convertir campos de Map a CampoAdicionalModel
      final camposModelo =
          _camposAdicionales.map((campo) {
            return CampoAdicionalModel(
              id: int.tryParse(campo['id'].toString()) ?? 0,
              nombreCampo: campo['nombre_campo'] ?? '',
              tipoCampo: campo['tipo_campo'] ?? '',
              obligatorio: campo['obligatorio'] == 1,
              modulo: campo['modulo'] ?? '',
              estadoMostrar: campo['estado_mostrar'] ?? '',
            );
          }).toList();

      final resultado =
          await ServiciosApiService.guardarValoresCamposAdicionales(
            servicioId: widget.servicioId!,
            campos: camposModelo,
            valores: widget.valoresCampos,
            modulo: widget.modulo,
          );

      if (resultado.isSuccess) {
        _mostrarMensaje(
          resultado.message ?? 'Campos adicionales guardados exitosamente',
          true,
        );
        return true;
      } else {
        _mostrarMensaje(
          resultado.error ?? 'Error guardando campos adicionales',
          false,
        );
        return false;
      }
    } catch (e) {
      _mostrarMensaje('Error inesperado: $e', false);
      return false;
    }
  }

  /// ✅ NUEVO: Validar que todos los campos obligatorios están completos
  bool validarCamposObligatorios() {
    final camposObligatoriosIncompletos = <String>[];

    for (var campo in _camposAdicionales) {
      final campoId = int.tryParse(campo['id'].toString());
      final obligatorio = campo['obligatorio'] == 1;
      final nombreCampo = campo['nombre_campo'] ?? 'Campo';

      if (obligatorio && campoId != null) {
        final valor = widget.valoresCampos[campoId];

        // Validar segn el tipo de campo
        bool estaVacio = _validarValorVacioPorTipo(valor, campo['tipo_campo']);

        if (estaVacio) {
          camposObligatoriosIncompletos.add(nombreCampo);
        }
      }
    }

    // Si hay campos incompletos, mostrar mensaje
    if (camposObligatoriosIncompletos.isNotEmpty) {
      _mostrarErrorCamposObligatorios(camposObligatoriosIncompletos);
      return false;
    }

    return true;
  }

  /// 🔍 NUEVO: Validar si un valor está vacío según el tipo de campo
  bool _validarValorVacioPorTipo(dynamic valor, String tipoCampo) {
    if (valor == null) return true;

    switch (tipoCampo.toLowerCase()) {
      case 'texto':
      case 'párrafo':
      case 'link':
        return valor.toString().trim().isEmpty;

      case 'entero':
      case 'decimal':
      case 'moneda':
        return valor == null || (valor is String && valor.trim().isEmpty);

      case 'fecha':
        return valor == null || (valor is String && valor.trim().isEmpty);

      case 'hora':
        return valor == null || (valor is String && valor.trim().isEmpty);

      case 'fecha y hora':
      case 'datetime':
        return valor == null || (valor is String && valor.trim().isEmpty);

      case 'imagen':
      case 'archivo':
        if (valor is Map<String, dynamic>) {
          return valor.isEmpty ||
              valor['nombre'] == null ||
              valor['nombre'].toString().trim().isEmpty;
        }
        return valor.toString().trim().isEmpty;

      case 'booleano':
        // Los campos booleanos pueden ser false, eso no cuenta como vacío
        return false;

      default:
        return valor.toString().trim().isEmpty;
    }
  }

  /// ? NUEVO: Mostrar mensaje de error para campos obligatorios
  void _mostrarErrorCamposObligatorios(List<String> camposFaltantes) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Campos Obligatorios',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Los siguientes campos adicionales son obligatorios y deben ser completados antes de cambiar el estado:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          camposFaltantes.map((campo) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: Colors.orange.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      campo,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Por favor, complete estos campos e intente nuevamente.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
    }
  }

  /// ⚙️ NUEVO: Método público para validación externa
  bool puedeCambiarEstado({bool esAnulacion = false}) {
    // Si no hay campos adicionales, puede cambiar
    if (_camposAdicionales.isEmpty) {
      return true;
    }

    // ✅ NUEVO: Si es anulación, no validar obligatoriedad
    if (esAnulacion) {
      return true;
    }

    // Validar campos obligatorios solo si NO es anulación
    return validarCamposObligatorios();
  }

  /// ? NUEVO: Obtener lista de campos obligatorios faltantes (para uso externo)
  List<String> obtenerCamposObligatoriosFaltantes() {
    final camposFaltantes = <String>[];

    for (var campo in _camposAdicionales) {
      final campoId = int.tryParse(campo['id'].toString());
      final obligatorio = campo['obligatorio'] == 1;
      final nombreCampo = campo['nombre_campo'] ?? 'Campo';

      if (obligatorio && campoId != null) {
        final valor = widget.valoresCampos[campoId];
        bool estaVacio = _validarValorVacioPorTipo(valor, campo['tipo_campo']);

        if (estaVacio) {
          camposFaltantes.add(nombreCampo);
        }
      }
    }

    return camposFaltantes;
  }

  String _construirUrlArchivo(Map<String, dynamic> archivo) {
    if (archivo['ruta_publica'] != null) {
      return '${ServerConfig.instance.apiRoot()}/core/fields/ver_archivo_campo.php?ruta=${archivo['ruta_publica']}';
    }
    return '';
  }

  Widget _buildErrorContainer() {
    return Container(
      width: double.infinity,
      height: 120,
      color: Colors.red.shade100,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 32, color: Colors.red),
          SizedBox(height: 4),
          Text(
            'Error cargando',
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContainer() {
    return Container(
      width: double.infinity,
      height: 120,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.image(),
            color: Colors.grey,
            size: 40,
          ),
          SizedBox(height: 4),
          Text('Imagen', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  IconData _getIconoTipoArchivo(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  IconData _getIconoTipoCampo(String tipoCampo) {
    switch (tipoCampo.toLowerCase()) {
      case 'texto':
        return PhosphorIcons.textT();
      case 'párrafo':
        return PhosphorIcons.article();
      case 'fecha':
        return PhosphorIcons.calendar();
      case 'dropdown':
        return PhosphorIcons.caretDown();
      case 'hora':
        return PhosphorIcons.clock();
      case 'entero':
        return PhosphorIcons.hash();
      case 'decimal':
        return PhosphorIcons.calculator();
      case 'moneda':
        return PhosphorIcons.currencyDollar();
      case 'link':
        return PhosphorIcons.link();
      case 'imagen':
        return PhosphorIcons.image();
      case 'archivo':
        return PhosphorIcons.file();
      default:
        return PhosphorIcons.puzzlePiece();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Cargando campos adicionales...'),
          ],
        ),
      );
    }

    if (_camposAdicionales.isEmpty) {
      // Mostrar un mensaje informativo cuando no haya campos para el estado
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No hay campos adicionales configurados para este estado',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.extension, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Campos Adicionales',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Informacin especfica para este estado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_camposAdicionales.length} campo${_camposAdicionales.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido de campos
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ? Indicador de carga para subida de archivos
                if (_isUploadingFile)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Subiendo archivo...'),
                      ],
                    ),
                  ),

                // Campos adicionales
                ..._camposAdicionales.map((campo) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label del campo
                        Row(
                          children: [
                            Text(
                              campo['nombre_campo'] ?? 'Campo',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (campo['obligatorio'] == 1) ...[
                              const SizedBox(width: 4),
                              const Text(
                                '*',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Widget del campo segn su tipo
                        _buildCampoSegunTipo(campo),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
