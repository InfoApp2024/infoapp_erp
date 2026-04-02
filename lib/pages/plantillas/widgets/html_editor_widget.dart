import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/plantilla_provider.dart';
import '../utils/code_editing_controller.dart';

class HtmlEditorWidget extends StatefulWidget {
  const HtmlEditorWidget({super.key});

  @override
  State<HtmlEditorWidget> createState() => HtmlEditorWidgetState();
}

class HtmlEditorWidgetState extends State<HtmlEditorWidget> {
  final CodeEditingController _htmlController = CodeEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _numbersScrollController = ScrollController();
  int _lineCount = 1;

  /// Inserta un tag en la posición actual del cursor.
  void insertTag(String tag) {
    final text = _htmlController.text;
    final selection = _htmlController.selection;
    
    // Si no hay selección o es inválida, insertar al final
    if (!selection.isValid) {
      _htmlController.text = text + tag;
      return;
    }

    final newText = text.replaceRange(selection.start, selection.end, tag);
    final newSelection = TextSelection.collapsed(offset: selection.start + tag.length);
    
    _htmlController.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );
    
    // Devolver el foco al editor
    _focusNode.requestFocus();
    
    // Guardar cambio localmente
    _saveContent();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialContent();
    
    // Sincronizar scroll entre números y editor
    _scrollController.addListener(() {
      if (_numbersScrollController.hasClients) {
        _numbersScrollController.jumpTo(_scrollController.offset);
      }
    });

    _htmlController.addListener(_updateLineCount);
  }

  void _updateLineCount() {
    final newCount = _htmlController.text.split('\n').length;
    if (newCount != _lineCount) {
      if (mounted) setState(() => _lineCount = newCount);
    }
  }

  void _loadInitialContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PlantillaProvider>();
      var plantilla = provider.currentPlantilla;

      // Si es una plantilla existente pero sin contenido, cargar el detalle
      if (plantilla != null &&
          !plantilla.isNew &&
          plantilla.contenidoHtml.isEmpty &&
          plantilla.id != null) {
        await provider.loadPlantilla(plantilla.id!);
        plantilla = provider.currentPlantilla;
      }

      if (plantilla != null && plantilla.contenidoHtml.isNotEmpty) {
        String html = _decodeHtml(plantilla.contenidoHtml);
        _htmlController.text = html;
      } else if (plantilla == null || plantilla.isNew) {
        // Solo insertar plantilla base si es nueva (no existente)
        _insertTemplate();
      }
    });
  }

  String _decodeHtml(String html) {
    // Decodificar entidades HTML sin alterar la estructura (no remover ni cambiar tags)
    return html
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  Future<void> _saveContent({bool persist = false}) async {
    final html = _htmlController.text.trim();

    if (html.isNotEmpty) {
      final provider = context.read<PlantillaProvider>();
      // Guardar contenido en el estado actual
      provider.updateCurrentPlantillaField(contenidoHtml: html);

      // Si se solicitó persistir y la plantilla ya existe, actualizar en backend
      if (persist) {
        final plantilla = provider.currentPlantilla;
        if (plantilla != null && !plantilla.isNew) {
          final ok = await provider.updatePlantilla(plantilla);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? 'Plantilla actualizada'
                      : (provider.plantillasError ?? 'Error al actualizar'),
                ),
                backgroundColor: ok ? Colors.green : Colors.red,
              ),
            );
          }
        } else if (mounted) {
          // Para nuevas plantillas, solo guardamos contenido local, la creación requiere datos del tab General
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Contenido guardado. Use "Guardar" arriba para crear la plantilla',
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          );
        }
      } else if (mounted) {
        // Guardado de contenido local (auto‑save/validación)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Contenido guardado'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _validateTags() async {
    await _saveContent(); // Guardar primero, sin persistir a backend

    final provider = context.read<PlantillaProvider>();
    await provider.validateTags(_htmlController.text);

    if (mounted) {
      _showValidationDialog();
    }
  }

  void _showValidationDialog() {
    final provider = context.read<PlantillaProvider>();
    final result = provider.validationResult;

    if (result == null) return;

    final isValid = result['es_valido'] ?? false;
    final tagsValidos = result['tags_validos'] as List? ?? [];
    final tagsInvalidos = result['tags_invalidos'] as List? ?? [];
    final sugerencias = result['sugerencias'] as List? ?? [];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.warning,
                  color: isValid ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isValid ? 'Tags Válidos' : 'Tags Inválidos',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isValid) ...[
                      Text(
                        '✓ Todos los tags son válidos',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tags encontrados (${tagsValidos.length}):',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...tagsValidos
                          .take(10)
                          .map(
                            (tag) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '{{$tag}}',
                                    style: const TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (tagsValidos.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '... y ${tagsValidos.length - 10} más',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ] else ...[
                      Text(
                        '⚠ ${tagsInvalidos.length} tag(s) inválido(s)',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...sugerencias.map((sug) {
                        final tagInvalido = sug['tag_invalido'];
                        final sugs = sug['sugerencias'] as List? ?? [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '{{$tagInvalido}}',
                                      style: const TextStyle(
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (sugs.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Sugerencias:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...sugs
                                    .take(3)
                                    .map(
                                      (s) => Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8,
                                          top: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.arrow_right,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '{{${s['tag']}}}',
                                              style: const TextStyle(
                                                fontFamily: 'Courier',
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${s['similitud']}%)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  provider.clearValidationResult();
                  Navigator.pop(context);
                },
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  void _insertTemplate() {
    final template = '''<!DOCTYPE html>
<html lang="es">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Informe Técnico</title>
  <style>
    /* ESTILOS BASE (Compatibles con TCPDF y Navegadores) */
    body {
      font-family: 'Helvetica', 'Arial', sans-serif;
      font-size: 10pt;
      line-height: 1.4;
      color: #333;
      background-color: #fff;
      margin: 0;
      padding: 0;
    }

    /* LAYOUT PRINCIPAL CON TABLAS */
    table {
      width: 100%;
      border-collapse: collapse;
      border-spacing: 0;
      margin-bottom: 15px;
    }

    /* HEADER */
    .header-table {
      border-bottom: 2px solid #333;
      margin-bottom: 20px;
    }

    .logo-cell {
      width: 30%;
      text-align: left;
      vertical-align: middle;
    }

    .company-info-cell {
      width: 70%;
      text-align: right;
      vertical-align: middle;
    }

    .company-info h1 {
      margin: 0;
      font-size: 18pt;
      color: #000;
      text-transform: uppercase;
    }

    .company-info p {
      margin: 2px 0;
      font-size: 10pt;
      color: #555;
    }

    /* TÍTULOS DE SECCIÓN */
    h2 {
      font-size: 12pt;
      color: #2c3e50;
      border-bottom: 1px solid #bdc3c7;
      padding-bottom: 5px;
      margin-top: 15px;
      margin-bottom: 10px;
      text-transform: uppercase;
    }

    /* TABLAS DE DATOS */
    .data-table th,
    .data-table td {
      border: 1px solid #ddd;
      padding: 6px;
      text-align: left;
      font-size: 9pt;
    }

    .data-table th {
      background-color: #f2f2f2;
      font-weight: bold;
      color: #333;
    }

    .data-table td {
      background-color: #fff;
    }

    /* CAJAS DE TEXTO (Actividades, Descripción) */
    .text-box {
      background-color: #f9f9f9;
      border: 1px solid #ddd;
      padding: 10px;
      margin-bottom: 15px;
      text-align: justify;
      min-height: 50px;
    }

    /* FOTOS */
    .photos-container {
      text-align: center;
      width: 100%;
    }

    /* Estilo para los items de fotos generados por procesar_tags.php */
    .photo-item {
      display: inline-block;
      width: 45%;
      margin: 5px;
      vertical-align: top;
      text-align: center;
      border: 1px solid #eee;
      padding: 5px;
      background: #fff;
    }

    .photo-item img {
      max-width: 100%;
      height: auto;
      border: 1px solid #ccc;
    }

    .photo-caption {
      font-size: 8pt;
      color: #666;
      margin-top: 5px;
    }

    /* FIRMAS */
    .signatures-table {
      margin-top: 30px;
      page-break-inside: avoid;
    }

    .sig-box {
      text-align: center;
      padding: 10px;
    }

    .sig-line {
      border-top: 1px solid #000;
      width: 80%;
      margin: 10px auto 5px auto;
    }

    .sig-name {
      font-weight: bold;
      font-size: 10pt;
    }

    .sig-role {
      font-size: 9pt;
      color: #666;
    }

    .sig-img {
      max-height: 40px;
      max-width: 100px;
      margin-bottom: 5px;
    }

    /* Force signature image size in table cells */
    .sig-box img {
      max-width: 100px !important;
      max-height: 40px !important;
      width: 100px;
      height: auto;
    }

    /* FOOTER */
    .footer {
      margin-top: 30px;
      text-align: center;
      font-size: 8pt;
      color: #999;
      border-top: 1px solid #eee;
      padding-top: 10px;
    }
  </style>
</head>

<body>

  <!-- ENCABEZADO -->
  <table class="header-table" cellpadding="5">
    <tr>
      <td class="logo-cell">
        <!-- Logo de la empresa -->
        <img src="{{branding_logo_url}}" style="max-height: 70px; width: auto;" alt="Logo" />
      </td>
      <td class="company-info-cell">
        <div class="company-info">
          <!-- Estos datos se pueden hacer dinámicos si se agregan los tags correspondientes -->
          <h1>INFORME TÉCNICO</h1>
          <p>NIT: 900.000.000-0</p>
          <p>www.infoapp.com</p>
        </div>
      </td>
        </tr>
  </table>

  <!-- INFORMACIÓN DEL SERVICIO -->
  <h2>Información del Servicio</h2>
  <table class="data-table" cellspacing="0" cellpadding="5">
    <tr>
      <th width="15%">Orden Interna</th>
      <th width="20%">Cliente</th>
      <th width="15%">Orden Cliente</th>
      <th width="15%">Fecha</th>
      <th width="15%">Ciudad</th>
      <th width="10%">Horas</th>
      <th width="10%">Km</th>
    </tr>
    <tr>
      <td>{{o_servicio}}</td>
      <td>{{cliente_nombre}}</td>
      <td>{{orden_cliente}}</td>
      <td>{{fecha_ingreso}}</td>
      <td>{{cliente_ciudad}}</td>
      <td>{{equipo_horometro}}</td>
      <td>{{equipo_kilometraje}}</td>
    </tr>
  </table>

  <!-- DETALLES DEL SERVICIO -->
  <h2>Detalles del Servicio</h2>
  <table class="data-table" cellspacing="0" cellpadding="5">
    <tr>
      <th width="20%">Tipo Mantenimiento</th>
      <th width="25%">Responsable</th>
      <th width="20%">Planta</th>
      <th width="20%">Equipo</th>
      <th width="15%">Placa/Serie</th>
    </tr>
    <tr>
      <td>{{tipo_servicio}}</td>
      <td>{{tecnico_asignado}}</td>
      <td>{{cliente_planta}}</td>
      <td>{{equipo_nombre}}</td>
      <td>{{equipo_placa}}</td>
    </tr>
  </table>

  <!-- INFORMACIÓN ADICIONAL -->
  <h2>Información Adicional</h2>
  <table class="data-table" cellspacing="0" cellpadding="5">
    <tr>
      <th width="25%">Fecha Entrega</th>
      <th width="25%">Técnicos</th>
      <th width="25%">Tiempo Actividad</th>
      <th width="25%">Estado Final</th>
    </tr>
    <tr>
      <td>{{fecha_terminacion}}</td>
      <td>{{tecnicos_nombres}}</td>
      <td>{{tiempo_actividad}}</td>
      <td>{{estado_servicio}}</td>
    </tr>
  </table>

  <!-- REPUESTOS (Tabla dinámica) -->
  <h2>Repuestos Suministrados</h2>
  <table class="data-table" cellspacing="0" cellpadding="5">
    <tr>
      <th width="40%">Nombre del Repuesto</th>
      <th width="20%">Código</th>
      <th width="20%">Cantidad</th>
      <th width="20%">Tipo</th>
    </tr>
    <!-- Las filas se generan automáticamente con el tag {{repuestos_filas}} -->
    {{repuestos_filas}}
  </table>

  <!-- ACTIVIDAD REALIZADA -->
  <h2>Actividad Realizada</h2>
  <div class="text-box">
    {{descripcion_trabajo}}
  </div>

  <!-- REGISTRO FOTOGRÁFICO -->
  <h2>Registro Fotográfico</h2>
  <div class="photos-container">
    {{tabla_fotos_comparativa}}
  </div>

  <!-- FIRMAS -->
  <h2>Firmas</h2>
  <table class="signatures-table" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr>
      <!-- Firma Cliente / Recibe -->
      <td width="50%" align="center" valign="top">
        <table width="90%" cellpadding="0" cellspacing="0" border="0">
          <tr>
            <td height="60" align="center" valign="bottom"
              style="height: 60px; vertical-align: bottom; padding-bottom: 5px;">
              {{firma_cliente}}
            </td>
          </tr>
          <tr>
            <td style="border-top: 1px solid #000; height: 1px; font-size: 1px; line-height: 1px;">&nbsp;</td>
          </tr>
          <tr>
            <td align="center" style="padding-top: 5px;">
              <div class="sig-name">{{cliente_contacto}}</div>
              <div class="sig-role">Recibido a Satisfacción</div>
            </td>
          </tr>
        </table>
      </td>

      <!-- Firma Técnico / Realiza -->
      <td width="50%" align="center" valign="top">
        <table width="90%" cellpadding="0" cellspacing="0" border="0">
          <tr>
            <td height="60" align="center" valign="bottom"
              style="height: 60px; vertical-align: bottom; padding-bottom: 5px;">
              {{firma_tecnico}}
            </td>
          </tr>
          <tr>
            <td style="border-top: 1px solid #000; height: 1px; font-size: 1px; line-height: 1px;">&nbsp;</td>
          </tr>
          <tr>
            <td align="center" style="padding-top: 5px;">
              <div class="sig-name">{{tecnico_asignado}}</div>
              <div class="sig-role">Técnico Responsable</div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>

  <!-- FOOTER -->
  <div class="footer">
    <p>© Todos los derechos reservados - Generado por InfoApp</p>
  </div>

</body>

</html>''';

    _htmlController.text = template;
    _saveContent();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _saveContent(persist: true),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _validateTags,
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Validar Tags'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('¿Insertar plantilla base?'),
                          content: const Text(
                            'Esto reemplazará el contenido actual con una plantilla de ejemplo.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _insertTemplate();
                              },
                              child: const Text('Insertar'),
                            ),
                          ],
                        ),
                  );
                },
                icon: const Icon(Icons.file_copy, size: 18),
                label: const Text('Plantilla Base'),
              ),
              const Spacer(),
              Consumer<PlantillaProvider>(
                builder: (context, provider, child) {
                  final result = provider.validationResult;
                  if (result != null) {
                    final isValid = result['es_valido'] ?? false;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isValid ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isValid ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isValid ? Icons.check_circle : Icons.warning,
                            size: 16,
                            color: isValid ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isValid
                                ? 'Tags válidos ✓'
                                : '${result['tags_invalidos']?.length ?? 0} inválido(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isValid
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),

        // Editor de código PRO
        Expanded(
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Panel de Números de Línea
                Container(
                  width: 45,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    border: Border(right: BorderSide(color: Colors.grey[800]!)),
                  ),
                  child: ListView.builder(
                    controller: _numbersScrollController,
                    itemCount: _lineCount,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        height: 20, // Altura que coincida con el height: 1.5 y fontSize: 13
                        child: Text(
                          '${index + 1}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Área del Editor
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: TextField(
                      controller: _htmlController,
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: GoogleFonts.robotoMono(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Escribe tu HTML aquí o presiga "Plantilla Base"...',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      cursorColor: Colors.blue,
                      onChanged: (value) {
                        // Auto-guardar después de 2 segundos de inactividad
                        Future.delayed(const Duration(seconds: 2), () {
                          if (_htmlController.text == value) {
                            _saveContent(); 
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Tip: Usa los tags del panel izquierdo. Ej: {{equipo_marca}}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _htmlController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _numbersScrollController.dispose();
    super.dispose();
  }
}
