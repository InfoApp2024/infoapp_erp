// lib/pages/servicios/widgets/notas_modal.dart
import 'package:flutter/material.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../models/nota_model.dart';
import '../services/notas_service.dart';

class NotasModal extends StatefulWidget {
  final int idServicio;
  final String numeroServicio;
  final String descripcion;

  const NotasModal({
    super.key,
    required this.idServicio,
    required this.numeroServicio,
    required this.descripcion,
  });

  @override
  _NotasModalState createState() => _NotasModalState();
}

class _NotasModalState extends State<NotasModal> {
  final NotasService _notasService = NotasService();
  List<NotaModel> _notas = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentUserId;
  bool _hasChanged = false; // ✅ NUEVO: Track if any note was created/edited

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await AuthService.getUserData();
      final notas = await _notasService.listarNotas(widget.idServicio);
      if (mounted) {
        setState(() {
          _currentUserId =
              user != null ? int.tryParse(user['id']?.toString() ?? '') : null;
          _notas = notas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarCrearNotaDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nueva Nota'),
            content: SizedBox(
              width: 500,
              child: TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu nota aquí...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    try {
                      await _notasService.crearNota(
                        widget.idServicio,
                        controller.text.trim(),
                      );
                      if (mounted) {
                        setState(() {
                          _hasChanged = true; // ✅ Marcar cambio
                        });
                      }
                      Navigator.pop(context);
                      _loadData(); // Recargar notas
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  void _mostrarEditarNotaDialog(NotaModel nota) {
    if (nota.esAutomatica) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las notas automáticas de trazabilidad no son editables')),
      );
      return;
    }

    if (nota.usuarioId != _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo el creador puede editar esta nota')),
      );
      return;
    }

    final controller = TextEditingController(text: nota.nota);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Editar Nota'),
            content: SizedBox(
              width: 500,
              child: TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu nota aquí...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    try {
                      await _notasService.actualizarNota(
                        nota.id,
                        controller.text.trim(),
                      );
                      if (mounted) {
                        setState(() {
                          _hasChanged = true; // ✅ Marcar cambio
                        });
                      }
                      Navigator.pop(context);
                      _loadData(); // Recargar notas
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Actualizar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notas - Servicio #${widget.numeroServicio}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.descripcion,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, _hasChanged),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const Divider(height: 32),

            // Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? Center(
                        child: Text(
                          'Error: $_errorMessage',
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                      : _notas.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay notas registradas',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: _notas.length,
                        itemBuilder: (context, index) {
                          final nota = _notas[index];
                          final esCreador = nota.usuarioId == _currentUserId;
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primaryContainer,
                                            child: Text(
                                              nota.usuario.isNotEmpty
                                                  ? nota.usuario[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nota.usuario,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                '${nota.fecha} - ${nota.hora}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (esCreador && !nota.esAutomatica)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                          ),
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          onPressed:
                                              () => _mostrarEditarNotaDialog(
                                                nota,
                                              ),
                                          tooltip: 'Editar nota',
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      nota.nota,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
            const SizedBox(height: 24),

            // Footer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _mostrarCrearNotaDialog,
                icon: const Icon(Icons.add),
                label: const Text('AGREGAR NUEVA NOTA'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
