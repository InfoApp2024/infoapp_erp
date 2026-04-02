<?php
// listar.php - Listar clientes
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// Debug logging
define('DEBUG_LOG', __DIR__ . '/debug_listar.txt');
function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    file_put_contents(DEBUG_LOG, "[$time] $msg\n", FILE_APPEND);
}

require_once '../login/auth_middleware.php';

try {
    log_debug("Iniciando listar.php");
    $currentUser = requireAuth();
    logAccess($currentUser, 'clientes/listar.php', 'list_clients');

    require '../conexion.php';
    $conn->set_charset("utf8mb4"); // Ensure UTF-8

    // Parámetros
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 50;
    $offset = isset($_GET['offset']) ? (int) $_GET['offset'] : 0;
    $estado = isset($_GET['estado']) ? (int) $_GET['estado'] : null;

    // Explicitly select columns to avoid ambiguity and ensure nombre_completo is returned
    $sql = "SELECT 
                c.id, 
                c.tipo_persona, 
                c.documento_nit, 
                c.nombre_completo, 
                c.email, 
                c.telefono_principal, 
                c.telefono_secundario, 
                c.direccion, 
                c.ciudad_id, 
                c.limite_credito, 
                c.perfil, 
                c.regimen_tributario,
                c.codigo_ciiu,
                c.es_agente_retenedor,
                c.dv,
                c.email_facturacion,
                c.responsabilidad_fiscal_id,
                c.es_autorretenedor,
                c.es_gran_contribuyente,
                c.estado, 
                c.created_at, 
                c.id_user,
                ci.nombre as ciudad_nombre, 
                ci.departamento, 
                u.NOMBRE_USER as creado_por
            FROM clientes c
            LEFT JOIN ciudades ci ON c.ciudad_id = ci.id
            LEFT JOIN usuarios u ON c.id_user = u.id
            WHERE 1=1";

    $params = [];
    $types = "";

    if ($estado !== null) {
        $sql .= " AND c.estado = ?";
        $params[] = $estado;
        $types .= "i";
    }

    if (!empty($search)) {
        $sql .= " AND (c.nombre_completo LIKE ? OR c.documento_nit LIKE ? OR c.email LIKE ?)";
        $searchTerm = "%{$search}%";
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $types .= "sss";
    }

    $sql .= " ORDER BY c.created_at DESC LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";

    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    $stmt->execute();
    $result = $stmt->get_result();

    $clientes = [];
    while ($row = $result->fetch_assoc()) {
        // Convertir tipos numéricos
        $row['limite_credito'] = (float) $row['limite_credito'];
        // $row['perfil'] es string, no requiere casting
        $row['es_agente_retenedor'] = (bool) $row['es_agente_retenedor'];
        $row['es_autorretenedor'] = (bool) $row['es_autorretenedor'];
        $row['es_gran_contribuyente'] = (bool) $row['es_gran_contribuyente'];
        $row['estado'] = (int) $row['estado'];

        // Debug first row to check structure
        if (empty($clientes)) {
            log_debug("First row keys: " . implode(", ", array_keys($row)));
            log_debug("First row nombre_completo: " . ($row['nombre_completo'] ?? 'NULL'));
        }

        $clientes[] = $row;
    }

    log_debug("Total clientes: " . count($clientes));

    sendJsonResponse(successResponse($clientes));
} catch (Exception $e) {
    log_debug("Error: " . $e->getMessage());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
