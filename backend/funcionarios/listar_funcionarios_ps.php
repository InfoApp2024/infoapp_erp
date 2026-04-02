<?php
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/listar_funcionarios.php', 'view_funcionarios');

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Method not allowed'), 405);
    }

    require '../conexion.php';

    if (!$conn) {
        throw new Exception("DB connection error");
    }

    $empresa = isset($_GET['empresa']) ? trim($_GET['empresa']) : '';
    $cliente_id = isset($_GET['cliente_id']) ? (int) $_GET['cliente_id'] : null;

    $whereClause = "WHERE activo = 1";
    $params = [];
    $types = "";

    if ($empresa === 'null' || $empresa === 'undefined') {
        $empresa = '';
    }

    if ($cliente_id !== null && $cliente_id > 0) {
        $whereClause .= " AND cliente_id = ?";
        $params[] = $cliente_id;
        $types .= "i";
    } elseif (!empty($empresa)) {
        $whereClause .= " AND empresa LIKE ?";
        $params[] = "%" . $empresa . "%";
        $types .= "s";
    }

    $sql = "SELECT id, nombre, cargo, empresa, telefono, correo, activo FROM funcionario $whereClause ORDER BY nombre";

    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    $stmt->execute();
    $result = $stmt->get_result();

    $funcionarios = [];
    if ($result && $result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $funcionarios[] = [
                'id' => (int) $row['id'],
                'nombre' => $row['nombre'],
                'cargo' => $row['cargo'] ?? '',
                'empresa' => $row['empresa'] ?? '',
                'telefono' => $row['telefono'] ?? '',
                'correo' => $row['correo'] ?? '',
                'activo' => (int) ($row['activo'] ?? 1)
            ];
        }
    }

    sendJsonResponse([
        'success' => true,
        'funcionarios' => $funcionarios,
        'total' => count($funcionarios)
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn) && $conn !== null) {
    $conn->close();
}
?>
