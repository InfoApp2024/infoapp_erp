php
 Verificar campos adicionales usando tu API existente
header('Content-Type texthtml; charset=utf-8');

try {
    echo h2🔍 Verificación de Campos Adicionales (usando tu API)h2;
    echo pstrongTimestampstrong  . date('Y-m-d His') . p;
    echo hr;
    
     1. Obtener campos desde tu API
    echo h3📋 Obteniendo campos desde tu API...h3;
    $api_url = 'http192.168.1.67infoapplistar_campos_adicionales.php';
    echo pstrongURL APIstrong a href='$api_url' target='_blank'$api_urlap;
    
    $campos_json = @file_get_contents($api_url);
    
    if ($campos_json === false) {
        throw new Exception(No se pudo obtener datos de la API $api_url);
    }
    
    $campos = json_decode($campos_json, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception(Error decodificando JSON  . json_last_error_msg());
    }
    
    if (empty($campos)) {
        echo p style='color red;'❌ strongNO hay campos adicionales!strongp;
        exit();
    }
    
    echo p style='color green;'✅ strong . count($campos) .  campos encontradosstrongp;
    
     2. Mostrar tabla de campos
    echo table border='1' style='border-collapse collapse; width 100%;';
    echo tr style='background-color #f0f0f0;';
    echo thIDththNombreththTipoththMóduloththEstado IDththObligatorioththEstado Mostrarth;
    echo tr;
    
    $campos_validos_para_prueba = [];
    
    foreach ($campos as $campo) {
        $obligatorio = isset($campo['obligatorio']) && $campo['obligatorio'] == 1;
        $color_fila = $obligatorio  '#fff3cd'  '#ffffff';  Amarillo claro para obligatorios
        
        echo tr style='background-color $color_fila;';
        echo tdstrong{$campo['id']}strongtd;
        echo td{$campo['nombre_campo']}td;
        echo tdspan style='background-color #e7f3ff; padding 2px 6px; border-radius 3px;'{$campo['tipo_campo']}spantd;
        echo td{$campo['modulo']}td;
        echo td{$campo['estado_mostrar']}td;
        echo td . ($obligatorio  '⚠️ SÍ'  '✅ No') . td;
        echo td{$campo['nombre_estado']}td;
        echo tr;
        
         Recopilar campos válidos para prueba (no obligatorios primero)
        if (!$obligatorio && count($campos_validos_para_prueba)  3) {
            $campos_validos_para_prueba[] = $campo;
        }
    }
    echo table;
    
     Si no hay suficientes campos no obligatorios, agregar algunos obligatorios
    if (count($campos_validos_para_prueba)  3) {
        foreach ($campos as $campo) {
            if (count($campos_validos_para_prueba) = 3) break;
            if (!in_array($campo, $campos_validos_para_prueba)) {
                $campos_validos_para_prueba[] = $campo;
            }
        }
    }
    
    echo hr;
    
     3. Generar URLs de prueba
    echo h3🧪 URLs de Pruebah3;
    
    if (!empty($campos_validos_para_prueba)) {
        $ids_para_url = implode(',', array_column(array_slice($campos_validos_para_prueba, 0, 3), 'id'));
        
        echo h4🔗 Prueba con campos existentesh4;
        echo ul;
        echo lia href='guardar_valores_campos_adicionales_nuevo.phpservicio_id=1' target='_blank';
        echo 🚀 Probar guardado automático con servicio_id=1ali;
        echo lia href='guardar_valores_campos_adicionales_nuevo.phpdebug=1' target='_blank';
        echo 🐛 Ver información de debugali;
        echo ul;
        
        echo h4📝 Campos que se usarán en la pruebah4;
        echo ol;
        foreach (array_slice($campos_validos_para_prueba, 0, 3) as $campo) {
            $obligatorio_text = ($campo['obligatorio'] == 1)  ' (⚠️ Obligatorio)'  '';
            echo listrongID {$campo['id']}strong {$campo['nombre_campo']} ({$campo['tipo_campo']})$obligatorio_textli;
        }
        echo ol;
    }
    
    echo hr;
    
     4. Verificar conexión a BD también
    echo h3🗄️ Verificación de Base de Datosh3;
    
    try {
        $pdo = new PDO(mysqlhost=localhost;dbname=dev;charset=utf8mb4, root, );
        echo p style='color green;'✅ Conexión a BD exitosap;
        
         Verificar tabla de valores
        $stmt = $pdo-query(SELECT COUNT() as total FROM valores_campos_adicionales);
        $total_valores = $stmt-fetch()['total'];
        echo p📊 Valores guardados actualmente strong$total_valoresstrongp;
        
         Mostrar algunos valores existentes si los hay
        if ($total_valores  0) {
            echo h4📋 Últimos valores guardadosh4;
            $stmt = $pdo-query(
                SELECT v., c.nombre_campo 
                FROM valores_campos_adicionales v 
                LEFT JOIN campos_adicionales c ON v.campo_id = c.id 
                ORDER BY v.fecha_actualizacion DESC 
                LIMIT 5
            );
            $valores_recientes = $stmt-fetchAll(PDOFETCH_ASSOC);
            
            echo table border='1' style='border-collapse collapse;';
            echo tr style='background-color #f0f0f0;';
            echo thServicio IDththCampoththValorththFechath;
            echo tr;
            
            foreach ($valores_recientes as $valor) {
                $valor_mostrar = $valor['valor_texto']  $valor['valor_numero']  $valor['valor_fecha']  $valor['valor_hora']  'NULL';
                echo tr;
                echo td{$valor['servicio_id']}td;
                echo td{$valor['nombre_campo']} (ID {$valor['campo_id']})td;
                echo td$valor_mostrartd;
                echo td{$valor['fecha_actualizacion']}td;
                echo tr;
            }
            echo table;
        }
        
    } catch (Exception $e) {
        echo p style='color red;'❌ Error BD  . $e-getMessage() . p;
    }
    
} catch (Exception $e) {
    echo p style='color red;'❌ strongErrorstrong  . $e-getMessage() . p;
}


style
    body { font-family Arial, sans-serif; margin 20px; }
    table { margin 10px 0; }
    th, td { padding 8px; text-align left; }
    th { background-color #f0f0f0; }
    a { color #0066cc; text-decoration none; }
    ahover { text-decoration underline; }
    ul, ol { margin 10px 0; }
    li { margin 5px 0; }
style