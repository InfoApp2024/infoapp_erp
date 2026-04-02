import 'package:flutter/material.dart';

class RepuestoSeleccion {
  final int id;
  final String nombre;
  final int stock;
  int cantidad;

  RepuestoSeleccion({
    required this.id,
    required this.nombre,
    required this.stock,
    this.cantidad = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepuestoSeleccion &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SeleccionarRepuestosModal extends StatefulWidget {
  final List<RepuestoSeleccion> repuestosSeleccionados;
  final Future<List<RepuestoSeleccion>> Function()? cargarRepuestos;

  const SeleccionarRepuestosModal({
    super.key,
    required this.repuestosSeleccionados,
    this.cargarRepuestos,
  });

  @override
  State<SeleccionarRepuestosModal> createState() =>
      _SeleccionarRepuestosModalState();
}

class _SeleccionarRepuestosModalState extends State<SeleccionarRepuestosModal> {
  List<RepuestoSeleccion> _todosRepuestos = [];
  List<RepuestoSeleccion> _seleccionados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _seleccionados = List.from(widget.repuestosSeleccionados);
    _cargarRepuestos();
  }

  Future<void> _cargarRepuestos() async {
    setState(() => _isLoading = true);
    if (widget.cargarRepuestos != null) {
      _todosRepuestos = await widget.cargarRepuestos!();
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar repuestos del inventario'),
      content:
          _isLoading
              ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
              : SizedBox(
                width: 350,
                height: 400,
                child: ListView(
                  children:
                      _todosRepuestos.map((repuesto) {
                        final seleccionado = _seleccionados.firstWhere(
                          (r) => r.id == repuesto.id,
                          orElse:
                              () => RepuestoSeleccion(
                                id: repuesto.id,
                                nombre: repuesto.nombre,
                                stock: repuesto.stock,
                                cantidad: 0,
                              ),
                        );
                        return Card(
                          child: ListTile(
                            title: Text(repuesto.nombre),
                            subtitle: Text('Stock: ${repuesto.stock}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed:
                                      seleccionado.cantidad > 0
                                          ? () {
                                            setState(() {
                                              if (seleccionado.cantidad > 0) {
                                                seleccionado.cantidad--;
                                              }
                                            });
                                          }
                                          : null,
                                ),
                                SizedBox(
                                  width: 40,
                                  child: TextFormField(
                                    initialValue:
                                        seleccionado.cantidad > 0
                                            ? seleccionado.cantidad.toString()
                                            : '',
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (val) {
                                      final n = int.tryParse(val) ?? 0;
                                      setState(() {
                                        if (n <= repuesto.stock && n >= 0) {
                                          seleccionado.cantidad = n;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed:
                                      seleccionado.cantidad < repuesto.stock
                                          ? () {
                                            setState(() {
                                              if (seleccionado.cantidad <
                                                  repuesto.stock) {
                                                seleccionado.cantidad++;
                                              }
                                            });
                                          }
                                          : null,
                                ),
                                Checkbox(
                                  value: seleccionado.cantidad > 0,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true &&
                                          seleccionado.cantidad == 0) {
                                        seleccionado.cantidad = 1;
                                      } else if (checked == false) {
                                        seleccionado.cantidad = 0;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final seleccionados =
                _todosRepuestos
                    .map((r) {
                      final sel = _seleccionados.firstWhere(
                        (s) => s.id == r.id,
                        orElse:
                            () => RepuestoSeleccion(
                              id: r.id,
                              nombre: r.nombre,
                              stock: r.stock,
                              cantidad: 0,
                            ),
                      );
                      return sel.cantidad > 0
                          ? RepuestoSeleccion(
                            id: r.id,
                            nombre: r.nombre,
                            stock: r.stock,
                            cantidad: sel.cantidad,
                          )
                          : null;
                    })
                    .whereType<RepuestoSeleccion>()
                    .toList();
            Navigator.pop(context, seleccionados);
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
