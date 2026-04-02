<?php
// Enable CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept, Authorization');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

header("Content-Type: application/json");
require 'conexion.php';

try {
    // ✅ VERIFICAR SI EXISTEN SERVICIOS EN LA TABLA
    $stmt = $conn->prepare("SELECT COUNT(*) as total_servicios FROM servicios");
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    $total_servicios = intval($row['total_servicios']);
    $es_primer_servicio = ($total_servicios === 0);

    // ✅ OBTENER EL SIGUIENTE NÚMERO
    if ($es_primer_servicio) {
        $siguiente_numero = 1; // Primer servicio, usuario puede editar
    } else {
        // Calcular automáticamente el siguiente número
        $stmt = $conn->prepare("SELECT MAX(o_servicio) as ultimo_numero FROM servicios");
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $ultimo_numero = intval($row['ultimo_numero'] ?? 0);
        $siguiente_numero = $ultimo_numero + 1;
    }

    echo json_encode([
        'success' => true,
        'es_primer_servicio' => $es_primer_servicio,
        'siguiente_numero' => $siguiente_numero,
        'total_servicios' => $total_servicios,
        'debug_info' => [
            'tabla_vacia' => ($total_servicios === 0),
            'puede_editar' => $es_primer_servicio,
            'numero_sugerido' => $siguiente_numero
        ]
    ]);
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'es_primer_servicio' => false,
        'siguiente_numero' => 1
    ]);
}

if (isset($stmt))
    $stmt->close();
if (isset($conn))
    $conn->close();
