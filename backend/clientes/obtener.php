<?php
// obtener.php - Obtener un cliente por ID
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();

    require '../conexion.php';

    if (!isset($_GET['id'])) {
        throw new Exception('ID de cliente requerido');
    }

    $id = (int) $_GET['id'];

    $sql = "SELECT c.*, ci.nombre as ciudad_nombre, ci.departamento
            FROM clientes c
            LEFT JOIN ciudades ci ON c.ciudad_id = ci.id
            WHERE c.id = ?";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        throw new Exception('Cliente no encontrado');
    }

    $cliente = $result->fetch_assoc();

    // Casting
    $cliente['limite_credito'] = (float) $cliente['limite_credito'];
    // $cliente['valor_mo'] = (float)$cliente['valor_mo']; // Deprecated or renamed
    $cliente['es_agente_retenedor'] = (bool) $cliente['es_agente_retenedor'];
    $cliente['es_autorretenedor'] = (bool) $cliente['es_autorretenedor'];
    $cliente['es_gran_contribuyente'] = (bool) $cliente['es_gran_contribuyente'];
    $cliente['estado'] = (int) $cliente['estado'];

    // Obtener perfiles (tarifas por especialidad)
    $sqlPerfiles = "SELECT cp.id, cp.especialidad_id, cp.valor, e.nom_especi 
                    FROM cliente_perfiles cp
                    JOIN especialidades e ON cp.especialidad_id = e.id
                    WHERE cp.cliente_id = ?";
    $stmtP = $conn->prepare($sqlPerfiles);
    $stmtP->bind_param("i", $id);
    $stmtP->execute();
    $resP = $stmtP->get_result();

    $perfiles = [];
    while ($rowP = $resP->fetch_assoc()) {
        $rowP['valor'] = (float) $rowP['valor'];
        $perfiles[] = $rowP;
    }
    $cliente['perfiles'] = $perfiles;

    // Obtener funcionarios
    $sqlFuncs = "SELECT id, nombre, cargo, empresa, telefono, correo, activo 
                 FROM funcionario 
                 WHERE cliente_id = ? AND activo = 1";
    $stmtF = $conn->prepare($sqlFuncs);
    $stmtF->bind_param("i", $id);
    $stmtF->execute();
    $resF = $stmtF->get_result();

    $funcionarios = [];
    while ($rowF = $resF->fetch_assoc()) {
        $rowF['id'] = (int) $rowF['id'];
        $rowF['activo'] = (bool) $rowF['activo'];
        $funcionarios[] = $rowF;
    }
    $cliente['funcionarios'] = $funcionarios;

    sendJsonResponse(successResponse($cliente));
} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
