<?php
require_once __DIR__ . '/../login/auth_middleware.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Manejar preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    // Validar permiso
    requirePermission($conn, $currentUser['id'], 'servicios_actividades', 'crear', $currentUser['rol']);

    $data = json_decode(file_get_contents('php://input'), true);

    if (empty($data['actividades']) || !is_array($data['actividades'])) {
        throw new Exception('Se requiere un array de actividades');
    }

    // DEBUG: Log received activities count and system ID if present
    $debugMsg = "[" . date('Y-m-d H:i:s') . "] INFOAPP DEBUG: Iniciando importación de " . count($data['actividades']) . " actividades\n";
    file_put_contents(__DIR__ . '/../debug_import.log', $debugMsg, FILE_APPEND);

    $actividades = $data['actividades'];
    $sobrescribir = isset($data['sobrescribir']) ? (bool) $data['sobrescribir'] : false;
    $sistemaIdGlobal = isset($data['sistema_id']) ? (int) $data['sistema_id'] : null; // ✅ FALLBACK GLOBAL

    $insertadas = 0;
    $actualizadas = 0;
    $omitidas = 0;
    $errores = [];

    // Iniciar transacción
    $conn->autocommit(FALSE);

    foreach ($actividades as $index => $actividadData) {
        try {
            // Inicializar variables
            $nombreActividad = '';
            $cant_hora = 0.00;
            $num_tecnicos = 1;
            $id_user = null;
            $sistema_id = null;

            // Manejar si es string simple o array asociativo
            if (is_array($actividadData)) {
                $nombreActividad = trim($actividadData['actividad'] ?? '');
                $cant_hora = isset($actividadData['cant_hora']) ? (float) $actividadData['cant_hora'] : 0.00;
                $num_tecnicos = isset($actividadData['num_tecnicos']) ? (int) $actividadData['num_tecnicos'] : 1;
                $id_user = isset($actividadData['id_user']) ? (int) $actividadData['id_user'] : null;
                // Priorizar ID individual, luego el global
                $sistema_id = isset($actividadData['sistema_id']) ? (int) $actividadData['sistema_id'] : $sistemaIdGlobal; 
                $debugMsg = "[" . date('Y-m-d H:i:s') . "] INFOAPP DEBUG: Procesando actividad '{$nombreActividad}' con sistema_id: " . ($sistema_id ?? 'NULL') . "\n";
                file_put_contents(__DIR__ . '/../debug_import.log', $debugMsg, FILE_APPEND);
            } else {
                $nombreActividad = trim($actividadData);
            }

            // Validar
            if (empty($nombreActividad)) {
                $errores[] = "Línea " . ($index + 1) . ": Actividad vacía";
                $omitidas++;
                continue;
            }

            if (strlen($nombreActividad) < 3) {
                $errores[] = "Línea " . ($index + 1) . ": Actividad muy corta";
                $omitidas++;
                continue;
            }

            if (strlen($nombreActividad) > 255) {
                $errores[] = "Línea " . ($index + 1) . ": Actividad muy larga";
                $omitidas++;
                continue;
            }

            // Verificar si existe
            $sqlCheck = "SELECT id, activo FROM actividades_estandar WHERE actividad = ?";
            $stmtCheck = $conn->prepare($sqlCheck);
            $stmtCheck->bind_param("s", $nombreActividad);
            $stmtCheck->execute();
            $resultCheck = $stmtCheck->get_result();
            $existe = $resultCheck->fetch_assoc();
            $stmtCheck->close();

            if ($existe) {
                if ($sobrescribir) {
                    // Actualizar datos y activar si estaba inactiva
                    $sqlUpdate = "UPDATE actividades_estandar 
                                 SET activo = 1, 
                                     cant_hora = ?,
                                     num_tecnicos = ?,
                                     id_user = ?,
                                     sistema_id = ?,
                                     updated_at = CURRENT_TIMESTAMP 
                                 WHERE id = ?";
                    $stmtUpdate = $conn->prepare($sqlUpdate);
                    $stmtUpdate->bind_param("diiii", $cant_hora, $num_tecnicos, $id_user, $sistema_id, $existe['id']);
                    $stmtUpdate->execute();
                    $stmtUpdate->close();
                    $actualizadas++;
                } else {
                    $omitidas++;
                }
            } else {
                // Insertar nueva
                $sqlInsert = "INSERT INTO actividades_estandar (actividad, activo, cant_hora, num_tecnicos, id_user, sistema_id) 
                             VALUES (?, 1, ?, ?, ?, ?)";
                $stmtInsert = $conn->prepare($sqlInsert);
                $stmtInsert->bind_param("sdiii", $nombreActividad, $cant_hora, $num_tecnicos, $id_user, $sistema_id);
                $stmtInsert->execute();
                $stmtInsert->close();
                $insertadas++;
            }
        } catch (Exception $e) {
            $errores[] = "Línea " . ($index + 1) . ": " . $e->getMessage();
            $omitidas++;
        }
    }

    // Confirmar transacción
    $conn->commit();
    $conn->autocommit(TRUE);

    echo json_encode([
        'success' => true,
        'message' => 'Importación completada',
        'resumen' => [
            'total' => count($actividades),
            'insertadas' => $insertadas,
            'actualizadas' => $actualizadas,
            'omitidas' => $omitidas
        ],
        'errores' => $errores
    ]);
} catch (Exception $e) {
    // Revertir transacción
    $conn->rollback();
    $conn->autocommit(TRUE);

    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Error al importar actividades',
        'error' => $e->getMessage()
    ]);
}

$conn->close();
