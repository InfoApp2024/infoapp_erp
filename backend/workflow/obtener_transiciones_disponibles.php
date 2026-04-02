<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST");
header("Content-Type: application/json");
require '../conexion.php';

$input = json_decode(file_get_contents('php://input'), true);
$servicio_id = $input['servicio_id'] ?? null;
$nuevo_estado_id = $input['nuevo_estado_id'] ?? null;
$es_anulacion = $input['es_anulacion'] ?? false;
$saltar_transiciones = $input['saltar_transiciones'] ?? false;

if (!$servicio_id || !$nuevo_estado_id) {
    echo json_encode([
        'success' => false,
        'message' => 'ID del servicio y nuevo estado son requeridos'
    ]);
    exit;
}

// Verificar que el servicio existe
$stmt = $conn->prepare("SELECT estado, anular_servicio FROM servicios WHERE id = ?");
$stmt->bind_param("i", $servicio_id);
$stmt->execute();
$result = $stmt->get_result();
$servicio = $result->fetch_assoc();

if (!$servicio) {
    echo json_encode([
        'success' => false,
        'message' => 'Servicio no encontrado'
    ]);
    exit;
}

// Verificar que el servicio no esté anulado (a menos que sea una anulación)
if ($servicio['anular_servicio'] == 1 && !$es_anulacion) {
    echo json_encode([
        'success' => false,
        'message' => 'No se puede cambiar el estado de un servicio anulado'
    ]);
    exit;
}

// ✅ LÓGICA SIMPLIFICADA: Solo validar transiciones si NO se salta la validación
if (!$saltar_transiciones && !$es_anulacion) {
    // Obtener todos los estados ordenados para validar flujo secuencial
    $stmt = $conn->prepare("SELECT id FROM estados_proceso ORDER BY id");
    $stmt->execute();
    $result = $stmt->get_result();
    $estados_ordenados = [];
    while ($row = $result->fetch_assoc()) {
        $estados_ordenados[] = $row['id'];
    }

    $estado_actual_index = array_search($servicio['estado'], $estados_ordenados);
    $nuevo_estado_index = array_search($nuevo_estado_id, $estados_ordenados);

    // Validar que el nuevo estado sea el siguiente en secuencia o posterior
    if ($nuevo_estado_index <= $estado_actual_index) {
        echo json_encode([
            'success' => false,
            'message' => 'Solo se puede avanzar al siguiente estado o posteriores'
        ]);
        exit;
    }
}

// Verificar que el nuevo estado existe
$stmt = $conn->prepare("SELECT nombre_estado FROM estados_proceso WHERE id = ?");
$stmt->bind_param("i", $nuevo_estado_id);
$stmt->execute();
$result = $stmt->get_result();
$estado = $result->fetch_assoc();

if (!$estado) {
    echo json_encode([
        'success' => false,
        'message' => 'Estado de destino no válido'
    ]);
    exit;
}

// Actualizar el estado del servicio
$stmt = $conn->prepare("UPDATE servicios SET estado = ? WHERE id = ?");
$stmt->bind_param("ii", $nuevo_estado_id, $servicio_id);

if ($stmt->execute()) {
    echo json_encode([
        'success' => true,
        'message' => 'Estado actualizado a: ' . $estado['nombre_estado']
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Error al actualizar el estado'
    ]);
}

$stmt->close();
$conn->close();
?>