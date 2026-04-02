import 'package:flutter/material.dart';
import 'package:infoapp/main.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_autorizado_por.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_cliente.dart';

class DialogoCrearServicio extends StatefulWidget {
  final String actividadNombre;
  final String equipoNombre;
  final String? equipoEmpresa;
  final int? clienteId;
  final int? autorizadoPorId; // Nuevo parámetro

  const DialogoCrearServicio({
    super.key,
    required this.actividadNombre,
    required this.equipoNombre,
    this.equipoEmpresa,
    this.clienteId,
    this.autorizadoPorId, // Nuevo parámetro
  });

  @override
  State<DialogoCrearServicio> createState() => _DialogoCrearServicioState();
}

class _DialogoCrearServicioState extends State<DialogoCrearServicio> {
  final _formKey = GlobalKey<FormState>();
  
  final _notaController = TextEditingController();
  
  bool _isLoading = true;
  List<EstadoModel> _estados = [];
  List<String> _tiposMantenimientoList = [];
  List<String> _centrosCostoList = [];
  
  int? _autorizadoPorSeleccionado;
  int? _estadoSeleccionado;
  int? _clienteSeleccionado;
  String _ordenCliente = '';
  String? _tipoMantenimientoSeleccionado;
  String? _centroCostoSeleccionado;
  
  bool _esClienteRol = false;

  @override
  void initState() {
    super.initState();
    _clienteSeleccionado = widget.clienteId;
    _autorizadoPorSeleccionado = widget.autorizadoPorId; // Inicializar con el autorizador de la actividad
    _checkRol();
    _cargarDatos();
  }

  Future<void> _checkRol() async {
    final userData = await AuthService.getUserData();
    if (userData != null) {
      final rol = userData['rol']?.toString().toLowerCase() ?? '';
      if (rol == 'cliente') {
        setState(() {
          _esClienteRol = true;
          // Forzar el autorizador al funcionario_id del usuario logueado
          // Pero solo si no heredamos uno de la actividad
          _autorizadoPorSeleccionado ??= userData['funcionario_id'];
          // El cliente_id ya viene del token y se inyectó en el diálogo
          if (userData['cliente_id'] != null) {
             _clienteSeleccionado = userData['cliente_id'];
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // 1. Asegurar que los datos de sesión (rol, ids) estén cargadoss primero
      await _checkRol();

      // 2. Cargar listas maestras
      final results = await Future.wait([
        ServiciosApiService.listarEstados(modulo: 'servicio'),
        ServiciosApiService.listarTiposMantenimiento(),
        ServiciosApiService.listarCentrosCosto(),
      ]);
      
      if (mounted) {
        setState(() {
          _estados = results[0] as List<EstadoModel>;
          _tiposMantenimientoList = results[1] as List<String>;
          _centrosCostoList = results[2] as List<String>;
          
          // Establecer estado inicial por defecto (el primero)
          if (_estados.isNotEmpty && _estadoSeleccionado == null) {
            _estadoSeleccionado = _estados.first.id;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        MyApp.showSnackBar('Error cargando datos: $e', backgroundColor: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Servicio'),
      content: _isLoading
          ? const SizedBox(
              width: 450,
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información de contexto
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.build, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.actividadNombre,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.precision_manufacturing, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(widget.equipoNombre),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Cliente - Oculto para rol cliente
                    if (!_esClienteRol) ...[
                      CampoCliente(
                        clienteSeleccionado: _clienteSeleccionado,
                        enabled: widget.clienteId == null,
                        onChanged: (value) {
                          setState(() {
                            _clienteSeleccionado = value?.id;
                            // Resetear funcionario al cambiar cliente
                            _autorizadoPorSeleccionado = null;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Campo requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Autorizado por - Oculto para rol cliente
                    if (!_esClienteRol) ...[
                      CampoAutorizadoPor(
                        autorizadoPor: _autorizadoPorSeleccionado,
                        onChanged: (value) {
                          setState(() => _autorizadoPorSeleccionado = value);
                        },
                        clienteId: _clienteSeleccionado,
                        empresa: widget.equipoEmpresa,
                        validator: (value) {
                          if (value == null) {
                            return 'Campo requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Estado inicial
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Estado inicial *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      initialValue: _estadoSeleccionado,
                      items: _estados.map((estado) {
                        return DropdownMenuItem<int>(
                          value: estado.id,
                          child: Text(estado.nombre ?? 'Sin nombre'),
                        );
                      }).toList(),
                      onChanged: null, // Read-only as per requirements
                      validator: (value) {
                        if (value == null) {
                          return 'Campo requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Orden del cliente
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Orden del cliente',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                      ),
                      onChanged: (value) => _ordenCliente = value,
                    ),
                    const SizedBox(height: 16),
                    
                    // Tipo de mantenimiento
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Tipo de mantenimiento *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings),
                      ),
                      initialValue: _tipoMantenimientoSeleccionado,
                      items: _tiposMantenimientoList.map((tipo) {
                        return DropdownMenuItem<String>(
                          value: tipo,
                          child: Text(tipo[0].toUpperCase() + tipo.substring(1)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _tipoMantenimientoSeleccionado = value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Campo requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Centro de costo
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Centro de costo *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      initialValue: _centroCostoSeleccionado,
                      items: _centrosCostoList.map((centro) {
                        return DropdownMenuItem<String>(
                          value: centro,
                          child: Text(centro[0].toUpperCase() + centro.substring(1)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _centroCostoSeleccionado = value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Campo requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Nota del servicio
                    TextFormField(
                      controller: _notaController,
                      decoration: InputDecoration(
                        labelText: _esClienteRol ? 'Nota (Obligatoria) *' : 'Nota (Opcional)',
                        hintText: 'Ej: Revisión general requerida',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.note_add),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (_esClienteRol && (value == null || value.trim().isEmpty)) {
                          return 'La nota es obligatoria para clientes';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isLoading ? null : _confirmar,
          icon: const Icon(Icons.check),
          label: const Text('Crear Servicio'),
        ),
      ],
    );
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;

    if (_clienteSeleccionado == null) {
      MyApp.showSnackBar('Error: Cliente no identificado.', backgroundColor: Colors.red);
      return;
    }
    if (_autorizadoPorSeleccionado == null) {
       String errorMsg = _esClienteRol 
          ? 'Su usuario no tiene un Funcionario vinculado para autorizar.' 
          : 'Debe seleccionar quién autoriza el servicio.';
      MyApp.showSnackBar(errorMsg, backgroundColor: Colors.red);
      return;
    }
    if (_estadoSeleccionado == null) {
      MyApp.showSnackBar('Error: Seleccione un estado inicial.', backgroundColor: Colors.red);
      return;
    }

    Navigator.of(context).pop({
      'cliente_id': _clienteSeleccionado,
      'autorizado_por': _autorizadoPorSeleccionado,
      'estado_id': _estadoSeleccionado,
      'orden_cliente': _ordenCliente,
      'tipo_mantenimiento': _tipoMantenimientoSeleccionado ?? 'correctivo',
      'centro_costo': _centroCostoSeleccionado ?? '',
      'nota': _auditNota(),
    });
  }

  String _auditNota() {
    String nota = _notaController.text.trim();
    if (_esClienteRol) {
      // Si es cliente, registrar quién aprueba en la nota si no lo hizo manualmente
      if (!nota.toLowerCase().contains('aprueba')) {
         // Opcional: añadir context
      }
    }
    return nota;
  }
}
