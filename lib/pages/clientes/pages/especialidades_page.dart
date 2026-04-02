import 'package:flutter/material.dart';
import '../models/especialidad_model.dart';
import '../services/especialidades_service.dart';

class EspecialidadesPage extends StatefulWidget {
  const EspecialidadesPage({super.key});

  @override
  State<EspecialidadesPage> createState() => _EspecialidadesPageState();
}

class _EspecialidadesPageState extends State<EspecialidadesPage> {
  List<EspecialidadModel> _especialidades = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final list = await EspecialidadesService.listarEspecialidades();
    setState(() {
      _especialidades = list;
      _loading = false;
    });
  }

  Future<void> _crearOEditar([EspecialidadModel? espe]) async {
    final nombreCtrl = TextEditingController(text: espe?.nomEspeci ?? '');

    final guardado = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              espe == null ? 'Nueva Especialidad' : 'Editar Especialidad',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Especialidad',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nombreCtrl.text.isEmpty) return;

                  final nuevo = EspecialidadModel(
                    id: espe?.id,
                    nomEspeci: nombreCtrl.text.trim(),
                    valorHr: espe?.valorHr ?? 0.0,
                  );

                  bool ok;
                  if (espe == null) {
                    ok = await EspecialidadesService.crearEspecialidad(nuevo);
                  } else {
                    ok = await EspecialidadesService.actualizarEspecialidad(
                      nuevo,
                    );
                  }

                  if (ok && mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );

    if (guardado == true) {
      _cargar();
    }
  }

  Future<void> _eliminar(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar'),
            content: const Text(
              '¿Eliminar esta especialidad? Se eliminarán las tarifas asociadas en los clientes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final ok = await EspecialidadesService.eliminarEspecialidad(id);
      if (ok) _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Especialidades')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditar(),
        child: const Icon(Icons.add),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _especialidades.isEmpty
              ? const Center(child: Text('No hay especialidades registradas'))
              : ListView.builder(
                itemCount: _especialidades.length,
                itemBuilder: (ctx, i) {
                  final e = _especialidades[i];
                  return ListTile(
                    title: Text(e.nomEspeci),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _crearOEditar(e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminar(e.id!),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
