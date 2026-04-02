import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signature/signature.dart';

class SignaturePadWidget extends StatefulWidget {
  final String label;
  final Function(String?) onSignatureChanged;
  final String? initialSignature;
  final Color penColor;
  final double penStrokeWidth;

  const SignaturePadWidget({
    super.key,
    required this.label,
    required this.onSignatureChanged,
    this.initialSignature,
    this.penColor = Colors.black,
    this.penStrokeWidth = 3.0,
  });

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  late SignatureController _controller;
  bool _hasSignature = false;
  // _aplicada ya no es tan relevante visualmente si es automático, 
  // pero lo mantenemos interno si se necesita lógica.
  
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: widget.penStrokeWidth,
      penColor: widget.penColor,
      exportBackgroundColor: Colors.white,
    );

    // Listener para detectar cambios en la firma
    _controller.addListener(() {
      final hasPoints = _controller.points.isNotEmpty;
      if (hasPoints != _hasSignature) {
        setState(() {
          _hasSignature = hasPoints;
        });
      }

      // ✅ Auto-guardado con debounce (espera a que el usuario termine de trazar)
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        if (hasPoints) {
          _guardar(silent: true);
        }
      });
    });

    // Cargar firma inicial si existe
    if (widget.initialSignature != null &&
        widget.initialSignature!.isNotEmpty) {
      _loadInitialSignature();
    }
  }

  Future<void> _loadInitialSignature() async {
    try {
      // Convertir base64 a imagen y cargarla en el controller
      final base64String = widget.initialSignature!.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      // Nota: signature package a veces es complejo para re-hidratar puntos desde imagen.
      // Aquí asumimos que si hay una imagen, marcamos como que hay firma.
      // Pero para editarla sobre la misma, el package necesita puntos.
      // Si solo es visualización inicial:
      setState(() {
        _hasSignature = true;
      });
    } catch (e) {
      debugPrint('Error cargando firma inicial: $e');
    }
  }

  Future<void> _limpiar() async {
    _controller.clear();
    widget.onSignatureChanged(null);
    setState(() {
      _hasSignature = false;
    });
  }

  Future<void> _guardar({bool silent = false}) async {
    if (_controller.isEmpty) {
      widget.onSignatureChanged(null);
      return;
    }

    try {
      final signature = await _controller.toPngBytes();
      if (signature != null) {
        final base64String = 'data:image/png;base64,${base64Encode(signature)}';
        widget.onSignatureChanged(base64String);
        
        // Confirmación ligera solo si no es silenciosa (aunque ya no usaremos botón manual)
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(milliseconds: 1000),
              backgroundColor: Colors.green,
              content: Text('Firma actualizada'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al guardar firma: $e');
      widget.onSignatureChanged(null);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Text(
              widget.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Área de firma
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Indicador de estado
                if (_hasSignature)
                  Row(
                    children: [
                      Icon(PhosphorIcons.checkCircle(), color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Firma capturada',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(PhosphorIcons.pencil(), color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Dibuje su firma',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),

                // Botón limpiar
                TextButton.icon(
                  onPressed: _hasSignature ? _limpiar : null,
                  icon: Icon(PhosphorIcons.x()),
                  label: const Text('Limpiar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),

            // Instrucciones simplificadas
            const SizedBox(height: 8),
            const Text(
              'La firma se guarda automáticamente al terminar de dibujar.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


