<?php
// Configuración CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=utf-8');

// Manejar preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Función de logging
function logMessage($message) {
    error_log(date('Y-m-d H:i:s') . " - OBTENER_CAMPOS_ESTADO: " . $message . "\n", 3, "obtener_campos_estado.log");
}

try {
    logMessage("=== INICIO OBTENER CAMPOS POR ESTADO ===");
    
    // Verificar parámetros
    if (!isset($_GET['estado_id'])) {
        throw new Exception('estado_id es requerido');
    }
    
    $estado_id = intval($_GET['estado_id']);
    $modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : 'Servicios';
    
    if ($estado_id <= 0) {
        throw new Exception('estado_id debe ser mayor a 0');
    }
    
    logMessage("Estado ID: $estado_id, Módulo: $modulo");

    // ✅ CONEXIÓN CORREGIDA - Usar la misma configuración que obtener_valores_campos_adicionales.php
    $pdo = new PDO("mysql:host=localhost;dbname=u342171239_InfoApp_Test;charset=utf8mb4", "u342171239_Test", "Test_2025/-*");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    logMessage("Conexión establecida");

    // ✅ CONSULTA CORREGIDA - Adaptada a tu estructura real
    $stmt = $pdo->prepare("
        SELECT 
            ca.id,
            ca.nombre_campo,
            ca.tipo_campo,
            ca.obligatorio,
            ca.estado_mostrar,
            ca.modulo,
            ca.creado
        FROM campos_adicionales ca 
        WHERE ca.modulo = ?
        AND ca.estado_mostrar = ?
        ORDER BY ca.id ASC
    ");
    
    $stmt->execute([$modulo, $estado_id]);
    $campos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    logMessage("Campos encontrados: " . count($campos));
    
    // Procesar campos para asegurar tipos correctos
    $camposProcesados = [];
    
    foreach ($campos as $campo) {
        $camposProcesados[] = [
            'id' => intval($campo['id']),
            'nombre_campo' => $campo['nombre_campo'],
            'tipo_campo' => $campo['tipo_campo'],
            'obligatorio' => intval($campo['obligatorio']),
            'estado_mostrar' => $campo['estado_mostrar'],
            'modulo' => $campo['modulo'],
            'creado' => $campo['creado']
        ];
        
        logMessage("Campo procesado - ID {$campo['id']}: {$campo['nombre_campo']} (tipo: {$campo['tipo_campo']})");
    }
    
    // ✅ RESPUESTA EXITOSA
    $response = [
        'success' => true,
        'campos' => $camposProcesados,
        'total' => count($camposProcesados),
        'estado_id' => $estado_id,
        'modulo' => $modulo
    ];
    
    echo json_encode($response);
    logMessage("Respuesta enviada: " . count($camposProcesados) . " campos");
    
} catch (Exception $e) {
    $errorMsg = 'Error obteniendo campos por estado: ' . $e->getMessage();
    logMessage("ERROR: " . $errorMsg);
    logMessage("Stack trace: " . $e->getTraceAsString());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $errorMsg,
        'campos' => [],
        'total' => 0
    ]);
}

logMessage("=== FIN OBTENER CAMPOS POR ESTADO ===\n");
?>
