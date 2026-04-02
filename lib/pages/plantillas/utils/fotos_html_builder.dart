import '../../servicios/models/foto_model.dart';

String buildPairedFotosHtml({
  required List<FotoModel> antes,
  required List<FotoModel> despues,
}) {
  final buffer = StringBuffer();
  buffer.writeln('<table style="width:100%; border-collapse:collapse;">');
  final maxLen = antes.length > despues.length ? antes.length : despues.length;
  for (int i = 0; i < maxLen; i++) {
    buffer.writeln('<tr>');
    if (i < antes.length) {
      final fa = antes[i];
      buffer.writeln('<td style="width:50%; padding:6px; vertical-align:top;">');
      buffer.writeln('<div style="font-weight:bold; margin-bottom:4px;">ANTES</div>');
      buffer.writeln('<img src="${fa.urlImagen}" style="width:100%; height:auto;" />');
      if ((fa.descripcion ?? '').isNotEmpty) {
        buffer.writeln('<div style="font-size:12px; color:#555; margin-top:4px;">${fa.descripcion}</div>');
      }
      buffer.writeln('</td>');
    } else {
      buffer.writeln('<td style="width:50%; padding:6px;"></td>');
    }
    if (i < despues.length) {
      final fd = despues[i];
      buffer.writeln('<td style="width:50%; padding:6px; vertical-align:top;">');
      buffer.writeln('<div style="font-weight:bold; margin-bottom:4px;">DESPUÉS</div>');
      buffer.writeln('<img src="${fd.urlImagen}" style="width:100%; height:auto;" />');
      if ((fd.descripcion ?? '').isNotEmpty) {
        buffer.writeln('<div style="font-size:12px; color:#555; margin-top:4px;">${fd.descripcion}</div>');
      }
      buffer.writeln('</td>');
    } else {
      buffer.writeln('<td style="width:50%; padding:6px;"></td>');
    }
    buffer.writeln('</tr>');
  }
  buffer.writeln('</table>');
  return buffer.toString();
}

String buildFotosColumnHtml({
  required List<FotoModel> fotos,
  required String titulo,
}) {
  final buffer = StringBuffer();
  buffer.writeln('<div style="width:100%;">');
  buffer.writeln('<div style="font-weight:bold; margin-bottom:8px;">$titulo</div>');
  for (final f in fotos) {
    buffer.writeln('<div style="margin-bottom:12px;">');
    buffer.writeln('<img src="${f.urlImagen}" style="width:100%; height:auto;" />');
    if ((f.descripcion ?? '').isNotEmpty) {
      buffer.writeln('<div style="font-size:12px; color:#555; margin-top:4px;">${f.descripcion}</div>');
    }
    buffer.writeln('</div>');
  }
  buffer.writeln('</div>');
  return buffer.toString();
}
