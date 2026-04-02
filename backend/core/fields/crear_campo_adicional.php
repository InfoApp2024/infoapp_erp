<?php
require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../../conexion.php';
    
    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON');
    }

    $modulo = $input['modulo'] ?? null;
    $nombre_campo = $input['nombre_campo'] ?? null;
    $tipo_campo = $input['tipo_campo'] ?? null;
    $obligatorio = $input['obligatorio'] ?? false;
    $estado_mostrar = $input['estado_mostrar'] ?? null; // ✅ NUEVO CAMPO

    // Validaciones
    if (!$modulo || !$nombre_campo || !$tipo_campo) {
        throw new Exception('Módulo, nombre del campo y tipo son obligatorios');
    }

    // Validar tipos permitidos
    $tipos_validos = ['Texto', 'Párrafo', 'Fecha', 'Hora', 'Fecha y hora', 'Decimal', 'Moneda', 'Entero', 'Link', 'Imagen', 'Archivo'];
    if (!in_array($tipo_campo, $tipos_validos)) {
        throw new Exception('Tipo de campo no válido');
    }

    // Verificar que no exista un campo con el mismo nombre en el mismo módulo
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM campos_adicionales WHERE modulo = ? AND nombre_campo = ?");
    $stmt->bind_param("ss", $modulo, $nombre_campo);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    if ($row['count'] > 0) {
        throw new Exception('Ya existe un campo con ese nombre en el módulo seleccionado');
    }

    // ✅ INSERTAR CON EL NUEVO CAMPO estado_mostrar
    $stmt = $conn->prepare("
        INSERT INTO campos_adicionales (modulo, nombre_campo, tipo_campo, obligatorio, estado_mostrar) 
        VALUES (?, ?, ?, ?, ?)
    ");

    $obligatorio_int = $obligatorio ? 1 : 0;
    $estado_mostrar_val = $estado_mostrar === null ? null : intval($estado_mostrar);

    $stmt->bind_param("sssii", $modulo, $nombre_campo, $tipo_campo, $obligatorio_int, $estado_mostrar_val);

    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Campo adicional creado exitosamente',
            'id' => $conn->insert_id
        ]);
    } else {
        throw new Exception('Error al crear el campo: ' . $stmt->error);
    }

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

if (isset($stmt))
    $stmt->close();
if (isset($conn))
    $conn->close();
?>