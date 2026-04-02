import 'package:image_picker/image_picker.dart';

class EvidenciaSeleccionada {
  final XFile file;
  String comentario;
  int? actividadId;
  final bool isRemote; // ✅ NUEVO: Identificar si es una imagen ya subida

  EvidenciaSeleccionada({
    required this.file, 
    this.comentario = '',
    this.actividadId,
    this.isRemote = false,
  });
}
