<?php
/**
 * analizar_cotizacion.php
 * Endpoint evolucionado: Asistente de Auditoría Preventiva (IA).
 * Analiza integridad, rentabilidad y consistencia técnica.
 */
require_once '../login/auth_middleware.php';
define('AUTH_REQUIRED', true);
require_once __DIR__ . '/config.php';
require_once '../conexion.php';

header('Content-Type: application/json');

function getGeminiApiKey($conn) {
    $sql = "SELECT setting_value FROM app_settings WHERE setting_key = 'gemini_api_key' ORDER BY id DESC LIMIT 1";
    $result = $conn->query($sql);
    if ($result && $row = $result->fetch_assoc()) {
        require_once './encryption_helper.php';
        $decrypted = decryptData($row['setting_value']);
        if (!empty($decrypted)) return $decrypted;
    }
    return defined('GEMINI_API_KEY') ? GEMINI_API_KEY : null;
}

function callGemini($prompt, $apiKey) {
    $modelsToTry = ['gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-flash-latest'];
    $lastError = null;

    foreach ($modelsToTry as $model) {
        $url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=" . $apiKey;
        $payload = [
            'contents' => [['parts' => [['text' => $prompt]]]],
            'generationConfig' => [
                'temperature' => 0.1, // Baja temperatura para mayor consistencia en auditoría
                'maxOutputTokens' => 2048,
            ]
        ];

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $decoded = json_decode($response, true);
        if ($httpCode === 200 && isset($decoded['candidates'][0]['content']['parts'][0]['text'])) {
            return $decoded['candidates'][0]['content']['parts'][0]['text'];
        }
        $lastError = $decoded['error']['message'] ?? "HTTP $httpCode";
    }
    throw new Exception("Error IA Gemini: " . $lastError);
}

try {
    $currentUser = requireAuth();
    $servicio_id = $_GET['servicio_id'] ?? null;
    $force_refresh = isset($_GET['refresh']) && $_GET['refresh'] == '1';

    if (!$servicio_id) throw new Exception("ID del servicio es requerido");

    $apiKey = getGeminiApiKey($conn);
    if (!$apiKey) throw new Exception("No se encontró API Key de Gemini.");

    // 0. Obtener ciclo actual
    $sqlCiclo = "SELECT ciclo_actual FROM fac_audit_ciclos WHERE servicio_id = ?";
    $stmtC = $conn->prepare($sqlCiclo);
    $stmtC->bind_param("i", $servicio_id);
    $stmtC->execute();
    $resCiclo = $stmtC->get_result()->fetch_assoc();
    $cicloActual = $resCiclo['ciclo_actual'] ?? 1;
    $stmtC->close();

    // 1. Verificar persistencia (Si ya existe análisis para este ciclo, retornarlo)
    if (!$force_refresh) {
        $sqlLog = "SELECT analisis_text, fuente, created_at FROM fac_auditoria_ia_logs WHERE servicio_id = ? AND ciclo = ? ORDER BY id DESC LIMIT 1";
        $stmtL = $conn->prepare($sqlLog);
        $stmtL->bind_param("ii", $servicio_id, $cicloActual);
        $stmtL->execute();
        $logExistente = $stmtL->get_result()->fetch_assoc();
        $stmtL->close();

        if ($logExistente) {
            echo json_encode([
                'success' => true,
                'fuente' => $logExistente['fuente'],
                'analisis' => $logExistente['analisis_text'],
                'persisted' => true,
                'fecha' => $logExistente['created_at']
            ]);
            exit;
        }
    }

    // 2. Obtener datos del servicio actual
    $sqlActual = "SELECT s.id, s.o_servicio, s.cliente_id, c.nombre_completo as cliente_nombre,
                         e.id as equipo_id, e.nombre as equipo_nombre, e.marca, e.modelo,
                         ae.actividad as actividad_nombre,
                         fc.valor_snapshot as subtotal, fc.total_mano_obra, fc.total_repuestos
                  FROM servicios s
                  JOIN clientes c ON s.cliente_id = c.id
                  JOIN equipos e ON s.id_equipo = e.id
                  LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
                  JOIN fac_control_servicios fc ON s.id = fc.servicio_id
                  WHERE s.id = ?";
    $stmt = $conn->prepare($sqlActual);
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $servicioActual = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$servicioActual) throw new Exception("Servicio no encontrado.");

    // Obtener repuestos
    $sqlRep = "SELECT i.name, sr.cantidad, sr.costo_unitario FROM servicio_repuestos sr JOIN inventory_items i ON sr.inventory_item_id = i.id WHERE sr.servicio_id = ?";
    $stmtR = $conn->prepare($sqlRep);
    $stmtR->bind_param("i", $servicio_id);
    $stmtR->execute();
    $resR = $stmtR->get_result();
    $repuestosActuales = [];
    while ($row = $resR->fetch_assoc()) $repuestosActuales[] = $row;
    $stmtR->close();

    // Obtener descripciones técnicas (Operaciones)
    $sqlOps = "SELECT descripcion, observaciones FROM operaciones WHERE servicio_id = ? ORDER BY id ASC";
    $stmtO = $conn->prepare($sqlOps);
    $stmtO->bind_param("i", $servicio_id);
    $stmtO->execute();
    $resO = $stmtO->get_result();
    $opsText = "";
    while ($row = $resO->fetch_assoc()) {
        $opsText .= "Activity: {$row['descripcion']}. Obs: {$row['observaciones']}\n";
    }
    $stmtO->close();

    // 3. Obtener Históricos para Rentabilidad
    $historicos = [];
    $sqlH = "SELECT fc.valor_snapshot, fc.total_mano_obra, fc.total_repuestos
              FROM servicios s
              JOIN fac_control_servicios fc ON s.id = fc.servicio_id
              WHERE s.actividad_id = (SELECT actividad_id FROM servicios WHERE id = ?) 
              AND fc.estado_comercial_cache = 'FACTURADO' AND s.id <> ?
              ORDER BY s.fecha_registro DESC LIMIT 5";
    $stmtH = $conn->prepare($sqlH);
    $stmtH->bind_param("ii", $servicio_id, $servicio_id);
    $stmtH->execute();
    $resH = $stmtH->get_result();
    while ($row = $resH->fetch_assoc()) $historicos[] = $row;
    $stmtH->close();

    // Prompt Engineering
    $prompt = "Eres un Auditor Técnico Automotriz y Consultor Financiero Senior.\n";
    $prompt .= "Tu misión es realizar una 'Auditoría Preventiva IA' sobre la siguiente cotización/servicio.\n\n";
    
    $prompt .= "SERVICIO: {$servicioActual['actividad_nombre']}\n";
    $prompt .= "EQUIPO: {$servicioActual['equipo_nombre']} ({$servicioActual['marca']} {$servicioActual['modelo']})\n";
    $prompt .= "RESUMEN FINANCIERO: MO \${$servicioActual['total_mano_obra']} | Repuestos \${$servicioActual['total_repuestos']} | Total \${$servicioActual['subtotal']}\n";
    
    $prompt .= "\nDESCRIPCIÓN TÉCNICA (LEGALIZACIÓN):\n" . ($opsText ?: "No hay descripción técnica cargada.") . "\n";
    
    $prompt .= "\nREPUESTOS CARGADOS:\n";
    foreach ($repuestosActuales as $r) $prompt .= "- {$r['name']} (Cant: {$r['cantidad']})\n";

    $prompt .= "\nCONTEXTO HISTÓRICO (PROMEDIOS):\n";
    if (empty($historicos)) $prompt .= "No hay datos previos. Usa estándares de mercado.\n";
    else {
        $avgMO = array_sum(array_column($historicos, 'total_mano_obra')) / count($historicos);
        $prompt .= "Promedio histórico MO para esta actividad: \${$avgMO}\n";
    }

    $prompt .= "\nTAREAS DE AUDITORÍA:\n";
    $prompt .= "1. CROSS-CHECK: Cruza la descripción técnica con los repuestos. Ej: Si mencionan 'pastillas' pero no hay en repuestos, es inconsistente.\n";
    $prompt .= "2. RENTABILIDAD: Si la MO desvía > 20% del promedio, márcalo como riesgo.\n";
    $prompt .= "3. INTEGRIDAD: ¿La descripción es clara para un cliente final? Si es ambigua, alértalo.\n";
    
    $prompt .= "\nFORMATO DE RESPUESTA (Usa Markdown profesional):\n";
    $prompt .= "### [!] ALERTA: [Breve título de la alerta principal]\n";
    $prompt .= "**1. Consistencia Técnica:** [Análisis]\n";
    $prompt .= "**2. Rentabilidad y MO:** [Análisis comparativo]\n";
    $prompt .= "**3. Integridad Documental:** [Análisis]\n";
    $prompt .= "**Recomendación Proactiva:** [Consejo ejecutivo]\n\n";
    $prompt .= "IMPORTANTE: Tu respuesta debe ser concisa (máximo 150 palabras) y 100% en ESPAÑOL.\n";

    $analisis = callGemini($prompt, $apiKey);
    $fuente = !empty($historicos) ? "Historial Interno + Estándar IA" : "Principios de Auditoría IA";

    // 4. Guardar en persistencia
    $sqlInsert = "INSERT INTO fac_auditoria_ia_logs (servicio_id, ciclo, analisis_text, fuente) VALUES (?, ?, ?, ?)";
    $stmtI = $conn->prepare($sqlInsert);
    $stmtI->bind_param("iiss", $servicio_id, $cicloActual, $analisis, $fuente);
    $stmtI->execute();
    $stmtI->close();

    echo json_encode([
        'success' => true,
        'fuente' => $fuente,
        'analisis' => $analisis,
        'ciclo' => $cicloActual
    ]);

} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
