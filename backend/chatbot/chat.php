<?php
// backend/chatbot/chat.php
require_once '../login/auth_middleware.php';
require_once './config.php';
require_once __DIR__ . '/../conexion.php'; // Asegurar conexión DB para leer settings
require_once './encryption_helper.php';

header('Content-Type: application/json');

// --- Obtener API Key de la BD o Config ---
function getGeminiApiKey($conn, &$debugLog)
{
    // 1. Intentar leer de la BD (Prioridad: Lo que el usuario configure en la App)
    $sql = "SELECT setting_value FROM app_settings WHERE setting_key = 'gemini_api_key' ORDER BY id DESC LIMIT 1";
    $result = $conn->query($sql);

    if ($result && $row = $result->fetch_assoc()) {
        $encrypted = $row['setting_value'];
        $debugLog[] = "Found key in DB. Encrypted len: " . strlen($encrypted);
        $decrypted = decryptData($encrypted);
        if (!empty($decrypted)) {
            $debugLog[] = "Decryption successful. Key len: " . strlen($decrypted);
            return $decrypted;
        } else {
            $debugLog[] = "Decryption failed or empty.";
        }
    } else {
        $debugLog[] = "No key found in DB query.";
    }

    // 2. Fallback a config.php (Si no hay nada en BD o falla)
    if (defined('GEMINI_API_KEY') && !empty(GEMINI_API_KEY)) {
        $debugLog[] = "Using fallback from config.";
        return GEMINI_API_KEY;
    }

    return null;
}

$keyDebugLog = [];
$apiKey = getGeminiApiKey($conn, $keyDebugLog);
$usedKeySource = ($apiKey === GEMINI_API_KEY) ? 'config' : 'database';
// $keyDebugStr = implode("; ", $keyDebugLog);

if (!$apiKey) {
    echo json_encode(['response' => 'Error de configuración: No se encontró API Key de IA.']);
    exit;
}
// ------------------------------------------

// 1. Autenticación
try {
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'No autorizado']);
    exit;
}

// 2. Obtener mensaje del usuario
$input = json_decode(file_get_contents('php://input'), true);
$userMessage = $input['message'] ?? '';

if (empty($userMessage)) {
    echo json_encode(['response' => 'Por favor escribe algo.']);
    exit;
}

// --- Función para guardar historial ---
function saveChatHistory($conn, $userId, $message, $isUser)
{
    // Asegurar que la tabla existe (Lazy initialization)
    static $tableChecked = false;
    if (!$tableChecked) {
        $conn->query("CREATE TABLE IF NOT EXISTS chat_messages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            message TEXT NOT NULL,
            is_user BOOLEAN DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");
        $tableChecked = true;
    }

    $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, message, is_user) VALUES (?, ?, ?)");
    $isUserInt = $isUser ? 1 : 0;
    $stmt->bind_param("isi", $userId, $message, $isUserInt);
    $stmt->execute();
}

// Guardar mensaje del usuario
saveChatHistory($conn, $currentUser['id'], $userMessage, true);

// --- Función para generar Token temporal de PDF ---
function generatePdfToken($conn, $jwt)
{
    // Tabla para tokens temporales
    $conn->query("CREATE TABLE IF NOT EXISTS pdf_temp_links (
        id INT AUTO_INCREMENT PRIMARY KEY,
        token VARCHAR(64) NOT NULL UNIQUE,
        jwt TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");

    // Limpiar tokens viejos (> 24h)
    $conn->query("DELETE FROM pdf_temp_links WHERE created_at < NOW() - INTERVAL 1 DAY");

    $token = bin2hex(random_bytes(16)); // 32 chars
    $stmt = $conn->prepare("INSERT INTO pdf_temp_links (token, jwt) VALUES (?, ?)");
    $stmt->bind_param("ss", $token, $jwt);
    $stmt->execute();

    return $token;
}

// Función auxiliar para llamar a Gemini
function callGemini($prompt, $apiKey)
{
    $modelsToTry = [
        'gemini-1.5-flash',
        'gemini-1.5-flash-8b',
        'gemini-2.0-flash',
        'gemini-flash-latest'
    ];

    $lastError = null;

    foreach ($modelsToTry as $model) {
        // Usamos API v1beta para compatibilidad con nuevos modelos
        $url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=" . $apiKey;

        $data = [
            'contents' => [
                [
                    'parts' => [
                        ['text' => $prompt]
                    ]
                ]
            ]
        ];

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

        $response = curl_exec($ch);

        if (curl_errno($ch)) {
            $lastError = ['error' => curl_error($ch)];
            curl_close($ch);
            continue;
        }

        curl_close($ch);
        $decoded = json_decode($response, true);

        if (!$decoded || isset($decoded['error'])) {
            $lastError = $decoded ? $decoded : ['error' => 'Invalid JSON from Gemini', 'raw' => $response];
            continue;
        }

        $decoded['used_model'] = $model;
        return $decoded;
    }

    return $lastError ?? ['error' => 'All models failed'];
}

// 3. Paso 1: Detectar Intención y Filtros (NLU)
$systemPrompt = "
You are a database assistant for a Field Service Management app.
The user is asking a question about 'Services' (servicios).
Your job is to extract filters to query the database.

Database Schema context:
- Table 'servicios' (s) has columns: id, o_servicio (Service Number), orden_cliente (Client Order), nombre_emp (Client Name), tipo_mantenimiento, fecha_ingreso.
- Table 'estados_proceso' (e) has column: nombre_estado (Status Name).
- Table 'equipos' (eq) has column: nombre (Equipment Name).

Instructions:
1. Analyze the user's message: \"$userMessage\"
2. Determine if they are asking to list/count/find services (Action: 'query') or just chatting (Action: 'chat').
3. If 'query', extract values for these filters:
   - service_id (looks like a number e.g. 1155, or an order code)
   - status (matches 'nombre_estado')
   - client (matches 'nombre_emp')
   - equipment (matches 'nombre')
   - limit (default 5, max 20)
   - report (boolean, true if user asks for report/pdf/informe/descargar)
   - query_type (string: 'list' | 'count' | 'sum_cost'). 
     - 'count' if asking 'how many', 'total count'. 
     - 'sum_cost' if asking 'total cost', 'total value', 'sum of price', 'in pesos'.
     - 'list' if asking 'show me', 'which ones'. Default to 'list'.
4. Return ONLY a JSON object. No markdown, no explanation.

Example JSON:
{\"action\": \"query\", \"filters\": {\"service_id\": \"1155\", \"status\": null, \"client\": null, \"limit\": 5, \"report\": true, \"query_type\": \"list\"}}
";

$geminiResponse1 = callGemini($systemPrompt, $apiKey);
$responseText = $geminiResponse1['candidates'][0]['content']['parts'][0]['text'] ?? '';

// Limpiar posible markdown ```json ... ```
$responseText = preg_replace('/^```json/', '', $responseText);
$responseText = preg_replace('/```$/', '', $responseText);
$intent = json_decode($responseText, true);

if (!$intent || !isset($intent['action'])) {
    // Fallback si Gemini falla en estructura
    $intent = ['action' => 'chat'];
}

// 4. Paso 2: Ejecutar Acción
if ($intent['action'] === 'query') {
    // require_once '../conexion.php'; // Ya incluido al inicio

    $filters = $intent['filters'] ?? [];
    $where = ["1=1"];
    $params = [];
    $types = "";

    // Construir Query Dinámica
    if (!empty($filters['service_id'])) {
        // Buscar por ID exacto, o_servicio o orden_cliente
        $where[] = "(s.id = ? OR s.o_servicio = ? OR s.orden_cliente LIKE ?)";
        $sid = $filters['service_id'];
        $params[] = $sid;
        $params[] = $sid;
        $params[] = "%" . $sid . "%";
        $types .= "sss"; // Asumimos string para flexibilidad, MySQL convierte si es necesario
    }
    if (!empty($filters['status'])) {
        $where[] = "e.nombre_estado LIKE ?";
        $params[] = "%" . $filters['status'] . "%";
        $types .= "s";
    }
    if (!empty($filters['client'])) {
        $where[] = "s.nombre_emp LIKE ?";
        $params[] = "%" . $filters['client'] . "%";
        $types .= "s";
    }
    if (!empty($filters['equipment'])) {
        $where[] = "eq.nombre LIKE ?";
        $params[] = "%" . $filters['equipment'] . "%";
        $types .= "s";
    }

    $limit = isset($filters['limit']) ? intval($filters['limit']) : 5;
    $queryType = $filters['query_type'] ?? 'list';

    if ($queryType === 'count') {
        // --- QUERY TIPO: COUNT ---
        $sql = "SELECT COUNT(*) as total
                FROM servicios s
                LEFT JOIN estados_proceso e ON s.estado = e.id
                LEFT JOIN equipos eq ON s.id_equipo = eq.id
                WHERE " . implode(" AND ", $where);

        $stmt = $conn->prepare($sql);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $data = ['total_count' => $row['total'], 'query_type' => 'count'];

    } elseif ($queryType === 'sum_cost') {
        // --- QUERY TIPO: SUMA DE COSTOS (REPUESTOS) ---
        // Debemos hacer JOIN con servicio_repuestos
        $sql = "SELECT SUM(sr.cantidad * sr.costo_unitario) as total_value
                FROM servicios s
                JOIN servicio_repuestos sr ON s.id = sr.servicio_id
                LEFT JOIN estados_proceso e ON s.estado = e.id
                LEFT JOIN equipos eq ON s.id_equipo = eq.id
                WHERE " . implode(" AND ", $where);

        $stmt = $conn->prepare($sql);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();

        // Si es null (no hay repuestos), poner 0
        $totalVal = $row['total_value'] ?? 0;
        $data = ['total_cost_sum' => $totalVal, 'query_type' => 'sum_cost'];

    } else {
        // --- QUERY TIPO: LIST (Default) ---
        $sql = "SELECT s.id, s.o_servicio, s.orden_cliente, s.nombre_emp, s.tipo_mantenimiento, 
                       e.nombre_estado, eq.nombre as equipo, s.fecha_ingreso, s.fecha_finalizacion, s.placa 
                FROM servicios s
                LEFT JOIN estados_proceso e ON s.estado = e.id
                LEFT JOIN equipos eq ON s.id_equipo = eq.id
                WHERE " . implode(" AND ", $where) . "
                ORDER BY s.fecha_ingreso DESC
                LIMIT ?";

        $params[] = $limit;
        $types .= "i";

        $stmt = $conn->prepare($sql);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }

        $stmt->execute();
        $result = $stmt->get_result();
        $data = [];
        while ($row = $result->fetch_assoc()) {
            // ✅ Obtener Repuestos asociados al servicio
            $serviceId = $row['id'];
            $sqlRepuestos = "SELECT i.name as repuesto, i.sku, sr.cantidad, sr.costo_unitario, (sr.cantidad * sr.costo_unitario) as costo_total 
                             FROM servicio_repuestos sr 
                             JOIN inventory_items i ON sr.inventory_item_id = i.id 
                             WHERE sr.servicio_id = $serviceId";
            $resRep = $conn->query($sqlRepuestos);
            $repuestos = [];
            $totalCostoRepuestos = 0;

            if ($resRep) {
                while ($r = $resRep->fetch_assoc()) {
                    $repuestos[] = $r;
                    $totalCostoRepuestos += floatval($r['costo_total']);
                }
            }

            $row['repuestos'] = $repuestos;
            $row['total_costo_repuestos'] = $totalCostoRepuestos;

            $data[] = $row;
        }
    }

    // Paso 3: Generar Respuesta Final
    if (empty($data) && $queryType !== 'count') {
        $finalPrompt = "The user asked: \"$userMessage\". I queried the database for service ID/Order/Filters but found 0 results. Tell the user nicely that no services were found with those criteria.";
    } elseif ($queryType === 'count') {
        $finalPrompt = "The user asked: \"$userMessage\". 
         The database query was a COUNT. 
         Result: " . json_encode($data) . ". 
         
         Please answer the user's question about 'how many' based on the 'total_count' provided.
         Format: 'Hay un total de X servicios registrados...' (or similar). Language: Spanish.";
    } elseif ($queryType === 'sum_cost') {
        $finalPrompt = "The user asked: \"$userMessage\". 
         The database query was a SUM of COST. 
         Result: " . json_encode($data) . ". 
         
         Please answer the user's question about the 'total cost/value'.
         Format: 'El costo total de los repuestos registrados (según filtros) es de $XXX COP.' (Format as currency). Language: Spanish.";
    } else {
        // Verificar si solicitó reporte
        $reportLink = "";
        if (!empty($filters['report']) && count($data) === 1) {
            // Solo generar link si es un único servicio específico
            $svcId = $data[0]['id'];
            // Obtener token JWT actual
            $jwt = getTokenFromHeader();

            // Generar token corto temporal
            $shortToken = generatePdfToken($conn, $jwt);

            // Construir URL absoluta o relativa
            $protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http");
            $host = $_SERVER['HTTP_HOST'];
            $scriptDir = dirname($_SERVER['PHP_SELF']); // /.../backend/chatbot

            // URL limpia con token corto
            $url = "$protocol://$host$scriptDir/descargar_pdf_get.php?id=$svcId&t=$shortToken";

            $reportLink = "\n\n📄 **[Descargar Informe PDF]($url)**";
        }

        $dataJson = json_encode($data);
        $finalPrompt = "The user asked: \"$userMessage\". 
        Here is the database result: $dataJson. 
        Please summarize this information for the user in a friendly way. 
        If it's a specific service, give full details (Client, Equipment, Status, Date, Type).
        
        IMPORTANT:
        - If the user asks about spare parts (repuestos) or costs, list the items in 'repuestos' and the 'total_costo_repuestos'.
        - If 'repuestos' is empty, say there are no spare parts assigned.
        - If the user asked for a report/PDF and we found 1 service, mention that the download link is below.
        
        Format it nicely (maybe use bullet points). Language: Spanish.";

        // Append report link instruction
        if ($reportLink) {
            $finalPrompt .= "\n\nAlso, tell the user they can download the report using the link provided.";
        }
    }

    $geminiResponse2 = callGemini($finalPrompt, $apiKey);

    if (isset($geminiResponse2['error'])) {
        $errorMsg = $geminiResponse2['error']['message'] ?? 'Unknown error';
        $errorCode = $geminiResponse2['error']['code'] ?? 0;

        if ($errorCode == 429) {
            $debugKey = substr($apiKey, 0, 4) . '...' . substr($apiKey, -4);
            $finalAnswer = "⚠️ **Límite de uso alcanzado**\n\n" .
                "El sistema ha alcanzado su límite de consultas gratuitas. Por favor intenta en unos minutos.\n\n" .
                "_(Debug Info: Key Source: $usedKeySource | Key: $debugKey)_";
        } else {
            $finalAnswer = "Lo siento, ocurrió un error con el servicio de IA: " . $errorMsg;
        }
    } else {
        $finalAnswer = $geminiResponse2['candidates'][0]['content']['parts'][0]['text'] ?? 'Lo siento, hubo un error procesando los datos.';
    }

    // DEBUG: Agregar info de la key usada si es necesario
    $maskedKey = (strlen($apiKey) > 8) ? (substr($apiKey, 0, 4) . '...' . substr($apiKey, -4)) : 'Invalid Key';
    $modelUsed = $geminiResponse2['used_model'] ?? 'unknown';
    // Clean output for production
    // $finalAnswer .= "\n\n(Debug: Key Source: $usedKeySource | Key: $maskedKey | Model: $modelUsed | Trace: $keyDebugStr)";

    if (isset($reportLink) && !empty($reportLink)) {
        $finalAnswer .= $reportLink;
    }

    // Guardar respuesta del bot
    saveChatHistory($conn, $currentUser['id'], $finalAnswer, false);

    echo json_encode(['response' => $finalAnswer, 'data_debug' => $data]); // data_debug opcional

} else {
    // Chat normal
    $chatPrompt = "You are a helpful assistant for a Field Service App. User says: \"$userMessage\". Answer in Spanish.";
    $geminiResponse = callGemini($chatPrompt, $apiKey);

    // DEBUG: Ver qué devuelve Gemini
    if (isset($geminiResponse['error'])) {
        if (isset($geminiResponse['error']['code']) && $geminiResponse['error']['code'] == 429) {
            $maskedKey = (strlen($apiKey) > 8) ? (substr($apiKey, 0, 4) . '...' . substr($apiKey, -4)) : 'Invalid Key';
            $answer = "⚠️ **Límite de uso alcanzado**\n\nEl sistema ha alcanzado su límite de consultas gratuitas. Por favor intenta en unos minutos.";
        } else {
            $answer = "Error interno IA: " . ($geminiResponse['error']['message'] ?? 'Desconocido');
        }
    } else {
        $answer = $geminiResponse['candidates'][0]['content']['parts'][0]['text'] ?? 'Lo siento, no pude procesar tu mensaje.';
    }

    // Guardar respuesta del bot
    saveChatHistory($conn, $currentUser['id'], $answer, false);

    echo json_encode(['response' => $answer]);
}
