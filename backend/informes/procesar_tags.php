<?php
// procesar_tags.php
// Función para reemplazar tags en el HTML con datos reales

function procesarTags($html, $datos)
{
    log_debug("🔄 Iniciando procesamiento de tags...");

    $html_procesado = $html;
    $tags_reemplazados = 0;

    // ==================================================
    // 1. TAGS DE SERVICIO
    // ==================================================
    if (!empty($datos['servicio'])) {
        log_debug("📋 Procesando tags de servicio...");

        foreach ($datos['servicio'] as $campo => $valor) {
            $tag = '{{' . $campo . '}}';

            if (strpos($html_procesado, $tag) !== false) {
                // Interceptar campos de ID para mostrar nombres
                if (($campo === 'autorizado_por' || $campo === 'autorizado_por_id') && !empty($datos['servicio']['autorizado_por_nombre'])) {
                    $valor_formateado = htmlspecialchars($datos['servicio']['autorizado_por_nombre']);
                } elseif (($campo === 'responsable_id' || $campo === 'id_responsable') && !empty($datos['servicio']['responsable_nombre'])) {
                    $valor_formateado = htmlspecialchars($datos['servicio']['responsable_nombre']);
                } elseif ($campo === 'estado' && !empty($datos['servicio']['estado_nombre'])) {
                    $valor_formateado = htmlspecialchars($datos['servicio']['estado_nombre']);
                } else {
                    $valor_formateado = formatearValor($valor, $campo);
                }

                $html_procesado = str_replace($tag, $valor_formateado, $html_procesado);
                $tags_reemplazados++;
                log_debug("   ✓ Tag reemplazado: $tag → " . substr($valor_formateado, 0, 50));
            }
        }

        // Tags adicionales de actividad
        $tags_actividad = [
            '{{actividad_horas}}' => $datos['servicio']['actividad_horas'] ?? '0',
            '{{actividad_tecnicos}}' => $datos['servicio']['actividad_tecnicos'] ?? '1',
            '{{sistema_nombre}}' => $datos['servicio']['sistema_nombre'] ?? 'N/A'
        ];

        foreach ($tags_actividad as $tag => $valor) {
            if (strpos($html_procesado, $tag) !== false) {
                $html_procesado = str_replace($tag, htmlspecialchars($valor), $html_procesado);
                $tags_reemplazados++;
                log_debug("   ✓ Tag reemplazado: $tag → $valor");
            }
        }
    }

    // ==================================================
    // 2. TAGS DE EQUIPO
    // ==================================================
    if (!empty($datos['equipo'])) {
        log_debug("📋 Procesando tags de equipo...");

        foreach ($datos['equipo'] as $campo => $valor) {
            $tag = '{{equipo_' . $campo . '}}';

            if (strpos($html_procesado, $tag) !== false) {
                $valor_formateado = formatearValor($valor, $campo);
                $html_procesado = str_replace($tag, $valor_formateado, $html_procesado);
                $tags_reemplazados++;
                log_debug("   ✓ Tag reemplazado: $tag → " . substr($valor_formateado, 0, 50));
            }
        }
    }

    // ==================================================
    // 3. TAGS DE CLIENTE
    // ==================================================
    if (!empty($datos['cliente'])) {
        log_debug("📋 Procesando tags de cliente...");

        $tags_cliente = [
            '{{cliente_nombre}}' => $datos['cliente']['nombre'] ?? '',
            '{{cliente_ciudad}}' => $datos['cliente']['ciudad'] ?? '',
            '{{cliente_city}}' => $datos['cliente']['ciudad'] ?? '', // Alias solicitado
            '{{cliente_planta}}' => $datos['cliente']['planta'] ?? '',
            '{{cliente_codigo}}' => $datos['cliente']['codigo'] ?? ''
        ];

        foreach ($tags_cliente as $tag => $valor) {
            if (strpos($html_procesado, $tag) !== false) {
                $valor_formateado = formatearValor($valor, 'texto');
                $html_procesado = str_replace($tag, $valor_formateado, $html_procesado);
                $tags_reemplazados++;
                log_debug("   ✓ Tag reemplazado: $tag → $valor_formateado");
            }
        }
    }

    // ==================================================
    // 3.5. TAGS DE USUARIO CREADOR
    // ==================================================
    if (!empty($datos['usuario'])) {
        log_debug("📋 Procesando tags de usuario...");

        $tags_usuario = [
            '{{usuario_correo}}' => $datos['usuario']['CORREO'] ?? '',
            '{{usuario_telefono}}' => $datos['usuario']['TELEFONO'] ?? '',
            '{{usuario_nombre}}' => $row['usuario_nombre'] ?? $datos['usuario']['NOMBRE_USER'] ?? ''
        ];

        foreach ($tags_usuario as $tag => $valor) {
            if (strpos($html_procesado, $tag) !== false) {
                $valor_formateado = formatearValor($valor, 'texto');
                $html_procesado = str_replace($tag, $valor_formateado, $html_procesado);
                $tags_reemplazados++;
                log_debug("   ✓ Tag reemplazado: $tag → $valor_formateado");
            }
        }
    }

    // ==================================================
    // 4. TAGS DE CAMPOS ADICIONALES
    // ==================================================
    if (!empty($datos['campos_adicionales'])) {
        log_debug("📋 Procesando tags de campos adicionales...");

        foreach ($datos['campos_adicionales'] as $campo) {
            $nombre_slug = slugify($campo['nombre_campo']);
            $tag = '{{campo_' . $nombre_slug . '}}';

            if (strpos($html_procesado, $tag) !== false) {
                $valor_formateado = formatearValor($campo['valor'], $campo['tipo_campo']);
                $html_procesado = str_replace($tag, $valor_formateado, $html_procesado);
                $tags_reemplazados++;
                log_debug("   ✓ Tag reemplazado: $tag → " . substr($valor_formateado, 0, 50));
            }
        }
    }

    // ==================================================
    // 5. TAGS DE FOTOS (MÚLTIPLES)
    // ==================================================
    if (!empty($datos['fotos'])) {
        log_debug("📋 Procesando tags de fotos...");

        $fotos_antes_raw = [];
        $fotos_despues_raw = [];

        foreach ($datos['fotos'] as $foto) {
            if ($foto['tipo_foto'] === 'antes') {
                $fotos_antes_raw[] = $foto;
            } elseif ($foto['tipo_foto'] === 'despues') {
                $fotos_despues_raw[] = $foto;
            }
        }

        // Agrupar por filas usando orden_visualizacion
        $filas_fotos = [];

        // 1. Procesar fotos con orden explícito (> 0)
        $sin_orden_antes = [];
        foreach ($fotos_antes_raw as $foto) {
            $orden = (int) $foto['orden_visualizacion'];
            if ($orden > 0) {
                $filas_fotos[$orden]['antes'] = $foto;
            } else {
                $sin_orden_antes[] = $foto;
            }
        }

        $sin_orden_despues = [];
        foreach ($fotos_despues_raw as $foto) {
            $orden = (int) $foto['orden_visualizacion'];
            if ($orden > 0) {
                $filas_fotos[$orden]['despues'] = $foto;
            } else {
                $sin_orden_despues[] = $foto;
            }
        }

        // 2. Procesar fotos sin orden (rellenar huecos o añadir al final)
        $idx_antes = 1;
        foreach ($sin_orden_antes as $foto) {
            while (isset($filas_fotos[$idx_antes]['antes'])) {
                $idx_antes++;
            }
            $filas_fotos[$idx_antes]['antes'] = $foto;
        }

        $idx_despues = 1;
        foreach ($sin_orden_despues as $foto) {
            while (isset($filas_fotos[$idx_despues]['despues'])) {
                $idx_despues++;
            }
            $filas_fotos[$idx_despues]['despues'] = $foto;
        }

        // Ordenar las filas por índice
        ksort($filas_fotos);

        // Reconstruir listas planas ordenadas para otros tags
        $fotos_antes = [];
        $fotos_despues = [];

        foreach ($filas_fotos as $fila) {
            if (isset($fila['antes']))
                $fotos_antes[] = $fila['antes'];
            if (isset($fila['despues']))
                $fotos_despues[] = $fila['despues'];
        }

        log_debug("   📸 Fotos antes: " . count($fotos_antes));
        log_debug("   📸 Fotos después: " . count($fotos_despues));

        // Tag: {{foto_antes}} - Primera foto antes
        if (strpos($html_procesado, '{{foto_antes}}') !== false) {
            if (!empty($fotos_antes)) {
                $url = generarTagImagen($fotos_antes[0]['ruta_archivo'], '300px', true);
                $html_procesado = reemplazoInteligente($html_procesado, '{{foto_antes}}', $url, '300px');
                $tags_reemplazados++;
            } else {
                $html_procesado = str_replace('{{foto_antes}}', '<p style="color: #999;">Sin foto antes</p>', $html_procesado);
            }
        }

        // Tag: {{foto_despues}} - Primera foto después
        if (strpos($html_procesado, '{{foto_despues}}') !== false) {
            if (!empty($fotos_despues)) {
                $url = generarTagImagen($fotos_despues[0]['ruta_archivo'], '300px', true);
                $html_procesado = reemplazoInteligente($html_procesado, '{{foto_despues}}', $url, '300px');
                $tags_reemplazados++;
            } else {
                $html_procesado = str_replace('{{foto_despues}}', '<p style="color: #999;">Sin foto después</p>', $html_procesado);
            }
        }

        // Tag: {{fotos_antes_todas}} - Todas las fotos antes
        if (strpos($html_procesado, '{{fotos_antes_todas}}') !== false) {
            $html_fotos = '';
            foreach ($fotos_antes as $foto) {
                // Generar fuente y luego reemplazar inteligentemente
                $source = generarTagImagen($foto['ruta_archivo'], '300px', true);
                $img_tag = '<div class="photo-item">';
                $img_tag .= '<img src="' . $source . '" style="max-width: 300px; height: auto; border: 1px solid #ddd; border-radius: 5px;" />';
                if (!empty($foto['comentario'])) {
                    $img_tag .= '<p class="photo-caption">' . htmlspecialchars($foto['comentario']) . '</p>';
                }
                $img_tag .= '</div>';
                $html_fotos .= $img_tag;
            }
            $html_procesado = str_replace('{{fotos_antes_todas}}', $html_fotos ?: '<p style="color: #999;">Sin fotos antes</p>', $html_procesado);
            $tags_reemplazados++;
        }

        // Tag: {{fotos_despues_todas}} - Todas las fotos después
        if (strpos($html_procesado, '{{fotos_despues_todas}}') !== false) {
            $html_fotos = '';
            foreach ($fotos_despues as $foto) {
                $source = generarTagImagen($foto['ruta_archivo'], '300px', true);
                $img_tag = '<div class="photo-item">';
                $img_tag .= '<img src="' . $source . '" style="max-width: 300px; height: auto; border: 1px solid #ddd; border-radius: 5px;" />';
                if (!empty($foto['comentario'])) {
                    $img_tag .= '<p class="photo-caption">' . htmlspecialchars($foto['comentario']) . '</p>';
                }
                $img_tag .= '</div>';
                $html_fotos .= $img_tag;
            }
            $html_procesado = str_replace('{{fotos_despues_todas}}', $html_fotos ?: '<p style="color: #999;">Sin fotos después</p>', $html_procesado);
            $tags_reemplazados++;
        }

        // Tag: {{fotos_todas}} - Todas las fotos juntas
        if (strpos($html_procesado, '{{fotos_todas}}') !== false) {
            $todas_imgs = '';
            foreach ($datos['fotos'] as $foto) {
                $source = generarTagImagen($foto['ruta_archivo'], '300px', true);
                $todas_imgs .= '<img src="' . $source . '" style="max-width: 300px; height: auto; border: 1px solid #ddd; border-radius: 5px; margin: 5px;" /> ';
            }
            $html_procesado = str_replace('{{fotos_todas}}', $todas_imgs ?: '<p style="color: #999;">Sin fotos</p>', $html_procesado);
            $tags_reemplazados++;
        }

        // Tag: {{tabla_fotos_comparativa}} - Tabla comparativa Antes vs Después
        if (strpos($html_procesado, '{{tabla_fotos_comparativa}}') !== false) {
            if (!empty($filas_fotos)) {
                // Estilo de tabla para asegurar columnas del 50%
                $tabla_html = '<table width="100%" cellpadding="5" cellspacing="0" border="0">';
                $tabla_html .= '<thead><tr>
                    <th width="50%" align="center" style="font-weight:bold; background-color:#f2f2f2; border:1px solid #ddd;">FOTO ANTES</th>
                    <th width="50%" align="center" style="font-weight:bold; background-color:#f2f2f2; border:1px solid #ddd;">FOTO DESPUÉS</th>
                </tr></thead><tbody>';

                foreach ($filas_fotos as $fila) {
                    $tabla_html .= '<tr>';

                    // Columna Antes
                    $tabla_html .= '<td width="50%" align="center" style="border:1px solid #ddd; vertical-align:middle;">';
                    if (isset($fila['antes'])) {
                        // Usar 90% del ancho de la celda para la imagen
                        $img_tag = generarTagImagen($fila['antes']['ruta_archivo'], '90%');
                        $tabla_html .= '<div style="text-align:center; padding:5px;">' . $img_tag . '</div>';
                        if (!empty($fila['antes']['comentario'])) {
                            $tabla_html .= '<p style="font-size: 9pt; color: #555; margin-top:5px;">' . htmlspecialchars($fila['antes']['comentario']) . '</p>';
                        }
                    } else {
                        $tabla_html .= '&nbsp;';
                    }
                    $tabla_html .= '</td>';

                    // Columna Después
                    $tabla_html .= '<td width="50%" align="center" style="border:1px solid #ddd; vertical-align:middle;">';
                    if (isset($fila['despues'])) {
                        $img_tag = generarTagImagen($fila['despues']['ruta_archivo'], '90%');
                        $tabla_html .= '<div style="text-align:center; padding:5px;">' . $img_tag . '</div>';
                        if (!empty($fila['despues']['comentario'])) {
                            $tabla_html .= '<p style="font-size: 9pt; color: #555; margin-top:5px;">' . htmlspecialchars($fila['despues']['comentario']) . '</p>';
                        }
                    } else {
                        $tabla_html .= '&nbsp;';
                    }
                    $tabla_html .= '</td>';

                    $tabla_html .= '</tr>';
                }
                $tabla_html .= '</tbody></table>';

                $html_procesado = str_replace('{{tabla_fotos_comparativa}}', $tabla_html, $html_procesado);
                $tags_reemplazados++;
                log_debug("   ✓ Tag reemplazado: {{tabla_fotos_comparativa}} (" . count($filas_fotos) . " filas)");
            } else {
                $html_procesado = str_replace('{{tabla_fotos_comparativa}}', '<p style="color: #999; text-align: center;">Sin registro fotográfico</p>', $html_procesado);
            }
        }
    } else {
        log_debug("   ⚠️ No hay fotos en los datos");

        // Reemplazar tags de fotos con mensajes de "sin foto"
        $html_procesado = str_replace('{{foto_antes}}', '<p style="color: #999;">Sin foto antes</p>', $html_procesado);
        $html_procesado = str_replace('{{foto_despues}}', '<p style="color: #999;">Sin foto después</p>', $html_procesado);
        $html_procesado = str_replace('{{fotos_antes_todas}}', '<p style="color: #999;">Sin fotos antes</p>', $html_procesado);
        $html_procesado = str_replace('{{fotos_despues_todas}}', '<p style="color: #999;">Sin fotos después</p>', $html_procesado);
        $html_procesado = str_replace('{{fotos_todas}}', '<p style="color: #999;">Sin fotos</p>', $html_procesado);
        $html_procesado = str_replace('{{tabla_fotos_comparativa}}', '<p style="color: #999;">Sin registro fotográfico</p>', $html_procesado);
    }

    // ==================================================
    // 6. TAGS DE PERSONAL (MÚLTIPLES)
    // ==================================================
    if (!empty($datos['personal'])) {
        log_debug("📋 Procesando tags de personal...");

        $nombres_personal = [];
        foreach ($datos['personal'] as $p) {
            if (!empty($p['nombre_staff'])) {
                $nombres_personal[] = htmlspecialchars($p['nombre_staff']);
            }
        }

        log_debug("   👤 Personal encontrado: " . count($nombres_personal));

        // Tag: {{tecnico_asignado}} - Primer técnico
        if (strpos($html_procesado, '{{tecnico_asignado}}') !== false) {
            $valor = !empty($nombres_personal) ? $nombres_personal[0] : 'Sin asignar';
            $html_procesado = str_replace('{{tecnico_asignado}}', $valor, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{tecnico_asignado}} → $valor");
        }

        // Tag: {{tecnicos_nombres}} - Todos los técnicos separados por coma
        if (strpos($html_procesado, '{{tecnicos_nombres}}') !== false) {
            $valor = !empty($nombres_personal) ? implode(', ', $nombres_personal) : 'Sin asignar';
            $html_procesado = str_replace('{{tecnicos_nombres}}', $valor, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{tecnicos_nombres}} → $valor");
        }

        // Tag: {{tecnicos_lista}} - Lista HTML
        if (strpos($html_procesado, '{{tecnicos_lista}}') !== false) {
            $lista_html = '<ul class="tecnicos-list">';
            foreach ($datos['personal'] as $p) {
                if (!empty($p['nombre_staff'])) {
                    $lista_html .= '<li><strong>' . htmlspecialchars($p['nombre_staff']) . '</strong>';
                    if (!empty($p['cargo'])) {
                        $lista_html .= ' - ' . htmlspecialchars($p['cargo']);
                    }
                    $lista_html .= '</li>';
                }
            }
            $lista_html .= '</ul>';
            $html_procesado = str_replace('{{tecnicos_lista}}', $lista_html, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{tecnicos_lista}}");
        }
    } else {
        log_debug("   ⚠️ No hay personal en los datos");

        $html_procesado = str_replace('{{tecnico_asignado}}', 'Sin asignar', $html_procesado);
        $html_procesado = str_replace('{{tecnicos_nombres}}', 'Sin asignar', $html_procesado);
        $html_procesado = str_replace('{{tecnicos_lista}}', '<p style="color: #999;">Sin técnicos asignados</p>', $html_procesado);
    }

    // ==================================================================
    // OVERRIDE: Si hay firma registrada, {{tecnico_asignado}} debe mostrar
    // al firmante real (quien entregó), no al técnico asignado al servicio.
    // ==================================================================
    if (!empty($datos['firmas']['nombre_staff']) && $datos['firmas']['nombre_staff'] !== 'N/A') {
        $nombre_firmante = htmlspecialchars($datos['firmas']['nombre_staff']);
        $html_procesado = str_replace('{{tecnico_asignado}}', $nombre_firmante, $html_procesado);
        log_debug("   ✓ Override {{tecnico_asignado}} con firmante real → $nombre_firmante");
    }

    // ==================================================
    // 6.1 TAGS DE OPERACIONES
    // ==================================================
    if (!empty($datos['operaciones'])) {
        log_debug("📋 Procesando tags de operaciones...");

        $operaciones = $datos['operaciones'];

        // Operación principal (is_master = 1 o la primera)
        $op_principal = null;
        foreach ($operaciones as $op) {
            if (!empty($op['is_master'])) {
                $op_principal = $op;
                break;
            }
        }
        if (!$op_principal)
            $op_principal = $operaciones[0];

        // Tag: {{operacion_principal}} - Nombre/descripción de la operación maestra
        if (strpos($html_procesado, '{{operacion_principal}}') !== false) {
            $nombre_op = htmlspecialchars(
                $op_principal['actividad_nombre'] ?? $op_principal['descripcion'] ?? 'Servicio técnico'
            );
            $html_procesado = str_replace('{{operacion_principal}}', $nombre_op, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{operacion_principal}} → $nombre_op");
        }

        // Tag: {{operaciones_observaciones}} - Observaciones de la operación principal
        if (strpos($html_procesado, '{{operaciones_observaciones}}') !== false) {
            $obs = htmlspecialchars($op_principal['observaciones'] ?? '');
            $html_procesado = str_replace('{{operaciones_observaciones}}', $obs, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{operaciones_observaciones}}");
        }

        // Tag: {{operaciones_lista}} - Lista HTML con todas las operaciones
        if (strpos($html_procesado, '{{operaciones_lista}}') !== false) {
            $lista_html = '<ul style="margin:0; padding-left:18px;">';
            foreach ($operaciones as $op) {
                $nombre = htmlspecialchars($op['actividad_nombre'] ?? $op['descripcion'] ?? 'Operación');
                $obs_item = !empty($op['observaciones']) ? ' - <em>' . htmlspecialchars($op['observaciones']) . '</em>' : '';
                $lista_html .= '<li>' . $nombre . $obs_item . '</li>';
            }
            $lista_html .= '</ul>';
            $html_procesado = str_replace('{{operaciones_lista}}', $lista_html, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{operaciones_lista}} (" . count($operaciones) . " operaciones)");
        }

        // Tag: {{operaciones_tabla}} - Tabla HTML con todas las operaciones
        if (strpos($html_procesado, '{{operaciones_tabla}}') !== false) {
            $tabla_html = '<table style="width:100%; border-collapse:collapse; font-size:12px;">'
                . '<thead><tr>'
                . '<th style="border:1px solid #ccc; padding:4px 8px; background:#f5f5f5;">Operación</th>'
                . '<th style="border:1px solid #ccc; padding:4px 8px; background:#f5f5f5;">Descripción</th>'
                . '<th style="border:1px solid #ccc; padding:4px 8px; background:#f5f5f5;">Observaciones</th>'
                . '</tr></thead><tbody>';
            foreach ($operaciones as $op) {
                $nombre = htmlspecialchars($op['actividad_nombre'] ?? '');
                $desc = htmlspecialchars($op['descripcion'] ?? '');
                $obs = htmlspecialchars($op['observaciones'] ?? '');
                $tabla_html .= '<tr>'
                    . '<td style="border:1px solid #ccc; padding:4px 8px;">' . $nombre . '</td>'
                    . '<td style="border:1px solid #ccc; padding:4px 8px;">' . $desc . '</td>'
                    . '<td style="border:1px solid #ccc; padding:4px 8px;">' . $obs . '</td>'
                    . '</tr>';
            }
            $tabla_html .= '</tbody></table>';
            $html_procesado = str_replace('{{operaciones_tabla}}', $tabla_html, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{operaciones_tabla}} (" . count($operaciones) . " operaciones)");
        }
    } else {
        log_debug("   ⚠️ No hay operaciones en los datos");
        $html_procesado = str_replace('{{operaciones_lista}}', '<p style="color:#999;">Sin operaciones registradas</p>', $html_procesado);
        $html_procesado = str_replace('{{operaciones_tabla}}', '<p style="color:#999;">Sin operaciones registradas</p>', $html_procesado);
    }

    // ==================================================
    // 7. TAGS DE REPUESTOS (MÚLTIPLES)
    // ==================================================
    if (!empty($datos['repuestos'])) {
        log_debug("📋 Procesando tags de repuestos...");
        log_debug("   📦 Repuestos encontrados: " . count($datos['repuestos']));

        // Tag: {{repuestos_filas}} - Filas de tabla
        if (strpos($html_procesado, '{{repuestos_filas}}') !== false) {
            $filas_html = '';
            foreach ($datos['repuestos'] as $r) {
                $filas_html .= '<tr>';
                $filas_html .= '<td>' . htmlspecialchars($r['item_nombre'] ?? 'N/A') . '</td>';
                $filas_html .= '<td>' . htmlspecialchars($r['codigo'] ?? 'N/A') . '</td>';
                $filas_html .= '<td>' . htmlspecialchars($r['cantidad'] ?? '0') . '</td>';
                $filas_html .= '<td>' . htmlspecialchars($r['tipo'] ?? 'N/A') . '</td>';
                $filas_html .= '</tr>';
            }
            $html_procesado = str_replace('{{repuestos_filas}}', $filas_html, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{repuestos_filas}} (" . count($datos['repuestos']) . " repuestos)");
        }

        // Tag: {{repuestos_lista}} - Lista HTML
        if (strpos($html_procesado, '{{repuestos_lista}}') !== false) {
            $lista_html = '<ul class="repuestos-list">';
            foreach ($datos['repuestos'] as $r) {
                $lista_html .= '<li><strong>' . htmlspecialchars($r['item_nombre'] ?? 'Repuesto') . '</strong>';
                $lista_html .= ' (Cantidad: ' . htmlspecialchars($r['cantidad'] ?? '0');
                if (!empty($r['codigo'])) {
                    $lista_html .= ' - Código: ' . htmlspecialchars($r['codigo']);
                }
                $lista_html .= ')</li>';
            }
            $lista_html .= '</ul>';
            $html_procesado = str_replace('{{repuestos_lista}}', $lista_html, $html_procesado);
            $tags_reemplazados++;
            log_debug("   ✓ Tag reemplazado: {{repuestos_lista}}");
        }
    } else {
        log_debug("   ⚠️ No hay repuestos en los datos");

        $html_procesado = str_replace('{{repuestos_filas}}', '<tr><td colspan="4" style="text-align: center; color: #999;">No hay repuestos registrados</td></tr>', $html_procesado);
        $html_procesado = str_replace('{{repuestos_lista}}', '<p style="color: #999;">No hay repuestos registrados</p>', $html_procesado);
    }

    // ==================================================
    // 8. TAGS DE FIRMAS (TABLA firmas)
    // ==================================================
    if (!empty($datos['firmas'])) {
        log_debug("📋 Procesando tags de firmas...");

        $firmas = $datos['firmas'];

        // Tags de IDs
        $tags_firmas = [
            '{{firma_servicio_id}}' => $firmas['id_servicio'] ?? '',
            '{{firma_staff_id}}' => $firmas['id_staff_entrega'] ?? '',
            '{{firma_funcionario_id}}' => $firmas['id_funcionario_recibe'] ?? '',
            '{{firma_nota_entrega}}' => $firmas['nota_entrega'] ?? '',
            '{{firma_nota_recepcion}}' => $firmas['nota_recepcion'] ?? '',
            '{{firma_fecha_creacion}}' => !empty($firmas['created_at']) ? date('d/m/Y H:i', strtotime($firmas['created_at'])) : '',
            '{{firma_fecha_actualizacion}}' => !empty($firmas['updated_at']) ? date('d/m/Y H:i', strtotime($firmas['updated_at'])) : ''
        ];

        foreach ($tags_firmas as $tag => $valor) {
            if (strpos($html_procesado, $tag) !== false) {
                $html_procesado = str_replace($tag, htmlspecialchars($valor), $html_procesado);
                $tags_reemplazados++;
                log_debug("   ✓ Tag reemplazado: $tag → " . substr($valor, 0, 50));
            }
        }

        // Tags de imágenes de firma
        // Tag: {{firma_staff_imagen}} o {{firma_tecnico}}
        if (!empty($firmas['firma_staff_base64'])) {
            $base64 = $firmas['firma_staff_base64'];
            $img_source = (strpos($base64, 'data:image') === 0) ? $base64 : 'data:image/png;base64,' . $base64;

            $html_procesado = reemplazoInteligente($html_procesado, '{{firma_staff_imagen}}', $img_source, '160px');
            $html_procesado = reemplazoInteligente($html_procesado, '{{firma_tecnico}}', $img_source, '160px');
            $html_procesado = reemplazoInteligente($html_procesado, '{{firma_usuario_imagen}}', $img_source, '160px');
            $tags_reemplazados++;
        } else {
            $placeholder = '';
            $html_procesado = str_replace(['{{firma_staff_imagen}}', '{{firma_tecnico}}', '{{firma_usuario_imagen}}'], $placeholder, $html_procesado);
        }

        // Tag: {{firma_funcionario_imagen}} o {{firma_cliente}}
        if (!empty($firmas['firma_funcionario_base64'])) {
            $base64 = $firmas['firma_funcionario_base64'];
            $img_source = (strpos($base64, 'data:image') === 0) ? $base64 : 'data:image/png;base64,' . $base64;

            $html_procesado = reemplazoInteligente($html_procesado, '{{firma_funcionario_imagen}}', $img_source, '160px');
            $html_procesado = reemplazoInteligente($html_procesado, '{{firma_cliente}}', $img_source, '160px');
            $tags_reemplazados++;
        } else {
            $placeholder = '';
            $html_procesado = str_replace(['{{firma_funcionario_imagen}}', '{{firma_cliente}}'], $placeholder, $html_procesado);
        }

        // Tags de nombres y correos (si están disponibles)
        if (!empty($firmas['nombre_staff'])) {
            $html_procesado = str_replace('{{firma_staff_nombre}}', htmlspecialchars($firmas['nombre_staff']), $html_procesado);
            $html_procesado = str_replace('{{firma_usuario_nombre}}', htmlspecialchars($firmas['nombre_staff']), $html_procesado);
            $tags_reemplazados += 2;
        }

        if (!empty($firmas['correo_staff'])) {
            $html_procesado = str_replace('{{firma_staff_correo}}', htmlspecialchars($firmas['correo_staff']), $html_procesado);
            $html_procesado = str_replace('{{firma_usuario_correo}}', htmlspecialchars($firmas['correo_staff']), $html_procesado);
            $tags_reemplazados += 2;
        }

        if (!empty($firmas['nombre_funcionario'])) {
            $html_procesado = str_replace('{{firma_funcionario_nombre}}', htmlspecialchars($firmas['nombre_funcionario']), $html_procesado);
            $tags_reemplazados++;
        }

        // {{cliente_contacto}}: Siempre reemplazar con el nombre del funcionario que recibe
        $nombre_cliente_contacto = !empty($firmas['nombre_funcionario']) && $firmas['nombre_funcionario'] !== 'N/A'
            ? htmlspecialchars($firmas['nombre_funcionario'])
            : 'Sin especificar';
        $html_procesado = str_replace('{{cliente_contacto}}', $nombre_cliente_contacto, $html_procesado);
        $tags_reemplazados++;
        log_debug("   ✓ Tag reemplazado: {{cliente_contacto}} → $nombre_cliente_contacto");
    } else {
        log_debug("   ⚠️ No hay firmas en los datos");

        // Reemplazar tags de firmas con placeholders
        $placeholder_firma = '<p style="color: #999; font-style: italic;">Sin firma</p>';
        $html_procesado = str_replace('{{firma_staff_imagen}}', $placeholder_firma, $html_procesado);
        $html_procesado = str_replace('{{firma_funcionario_imagen}}', $placeholder_firma, $html_procesado);
        $html_procesado = str_replace('{{firma_tecnico}}', $placeholder_firma, $html_procesado);
        $html_procesado = str_replace('{{firma_cliente}}', $placeholder_firma, $html_procesado);
        $html_procesado = str_replace('{{firma_staff_nombre}}', 'N/A', $html_procesado);
        $html_procesado = str_replace('{{firma_funcionario_nombre}}', 'N/A', $html_procesado);
        $html_procesado = str_replace('{{cliente_contacto}}', 'Sin especificar', $html_procesado);
        $html_procesado = str_replace('{{firma_nota_entrega}}', '', $html_procesado);
        $html_procesado = str_replace('{{firma_nota_recepcion}}', '', $html_procesado);
    }

    log_debug("✅ Procesamiento completado. Tags reemplazados: $tags_reemplazados");

    // ==================================================
    // LIMPIEZA FINAL: Eliminar todos los {{tags}} no resueltos
    // Cualquier tag que no tenga valor en los datos se elimina
    // para que no aparezca el texto literal en el PDF.
    // ==================================================
    $html_procesado = preg_replace('/\{\{[^}]+\}\}/', '', $html_procesado);
    log_debug("🧹 Tags sin resolver eliminados del HTML final.");

    return $html_procesado;
}

// ==================================================
// FUNCIONES AUXILIARES
// ==================================================

function formatearValor($valor, $tipo)
{
    // Si es "0" para centro_costo, mostrar guion
    if ($tipo === 'centro_costo' && ($valor === '0' || $valor === 0)) {
        return '-';
    }

    if ($valor === null || $valor === '') {
        return '-';
    }

    // Formatear booleanos (0/1) a Si/No para campos específicos o por tipo
    $campos_booleanos = ['suministraron_repuestos', 'anular_servicio', 'es_finalizado', '¿repuestos suministrados?', '¿finalizado?', 'fines_de_semana'];
    if (in_array(strtolower($tipo), $campos_booleanos) || $tipo === 'tinyint(1)') {
        return ((int) $valor === 1) ? 'Si' : 'No';
    }

    // Formatear fechas
    if (strpos($tipo, 'fecha') !== false || $tipo === 'datetime' || $tipo === 'timestamp' || $tipo === 'date') {
        try {
            return date('d/m/Y H:i', strtotime($valor));
        } catch (Exception $e) {
            return $valor;
        }
    }

    // Formatear números decimales
    if (strpos($tipo, 'numero') !== false || $tipo === 'Decimal' || $tipo === 'Moneda') {
        return number_format((float) $valor, 2, ',', '.');
    }

    // Formatear enteros
    if ($tipo === 'Entero' || $tipo === 'int') {
        return number_format((float) $valor, 0, '', '');
    }

    return htmlspecialchars($valor);
}

function generarTagImagen($ruta, $width = '300px', $source_only = false)
{
    if (empty($ruta)) {
        return '<span style="color: #999; font-style: italic;">[Sin imagen]</span>';
    }

    // Si la ruta ya es una URL completa, usarla directamente
    if (strpos($ruta, 'http://') === 0 || strpos($ruta, 'https://') === 0) {
        return '<img src="' . htmlspecialchars($ruta) . '" style="max-width: ' . $width . '; height: auto; border: 1px solid #ddd; border-radius: 5px;" />';
    }

    // Si la ruta es absoluta del servidor, intentar usarla directamente o convertirla
    $server_root = '/home/u342171239/domains/novatechdevelopment.com/public_html';

    // Para evitar el error de etiquetas <img> anidadas si el usuario puso el tag dentro de un src="",
    // vamos a devolver solo la ruta/URL si detectamos que fallback es necesario o si es una ruta local.

    if (strpos($ruta, 'uploads/') === 0) {
        $local_path = $server_root . '/API_Infoapp/' . $ruta;
        if (file_exists($local_path)) {
            if ($source_only) {
                return htmlspecialchars($local_path);
            }
            return '<img src="' . htmlspecialchars($local_path) . '" style="max-width: ' . $width . '; height: auto; border: 1px solid #ddd; border-radius: 5px;" />';
        }
    }

    // Fallback a URL pública si lo anterior falla
    $url = $ruta;
    if (strpos($ruta, $server_root) === 0) {
        $url = str_replace($server_root, 'https://novatechdevelopment.com', $ruta);
    } elseif (strpos($ruta, '../') === 0) {
        $url = str_replace('../', 'https://migracion-infoapp.novatechdevelopment.com/API_Infoapp/', $ruta);
    } elseif (strpos($ruta, 'uploads/') === 0) {
        $url = 'https://migracion-infoapp.novatechdevelopment.com/API_Infoapp/' . $ruta;
    }

    if ($source_only) {
        return htmlspecialchars($url);
    }

    return '<img src="' . htmlspecialchars($url) . '" style="max-width: ' . $width . '; height: auto; border: 1px solid #ddd; border-radius: 5px;" />';
}

function slugify($text)
{
    $text = iconv('UTF-8', 'ASCII//TRANSLIT', $text);
    $text = strtolower($text);
    $text = preg_replace('/[^a-z0-9]+/', '_', $text);
    $text = trim($text, '_');
    return $text;
}

/**
 * Reemplaza un tag por el source o la etiqueta completa según el contexto
 */
function reemplazoInteligente($html, $tag, $source, $width = '300px')
{
    if (empty($source) || empty($tag))
        return $html;

    $img_tag = '<img src="' . $source . '" style="width: ' . $width . '; height: 70px; object-fit: contain; display: block; margin: 0 auto;" />';

    // Si el tag está dentro de un src="...", devolvemos solo el source
    if (preg_match('/src=["\']' . preg_quote($tag, '/') . '["\']/', $html)) {
        return str_replace($tag, $source, $html);
    }

    // De lo contrario, devolvemos la etiqueta completa
    return str_replace($tag, $img_tag, $html);
}
