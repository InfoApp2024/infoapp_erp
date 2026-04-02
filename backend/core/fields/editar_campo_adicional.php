<?php
require_once '../../login/auth_middleware.php';

$currentUser = requireAuth();
require '../../conexion.php';

$data = json_decode(file_get_contents("php://input"));

if (
    isset($data->id) &&
    isset($data->modulo) &&
    isset($data->nombre_campo) &&
    isset($data->tipo_campo) &&
    isset($data->obligatorio)
    // ✅ NUEVO: Validar estado_mostrar (puede ser null)
) {
    $id = $data->id;
    $modulo = $data->modulo;
    $nombre_campo = $data->nombre_campo;
    $tipo_campo = $data->tipo_campo;
    $obligatorio = $data->obligatorio ? 1 : 0;
    $estado_mostrar = isset($data->estado_mostrar) ? $data->estado_mostrar : null;

    // ✅ ACTUALIZADO: Incluir estado_mostrar en el UPDATE
    $sql = "UPDATE campos_adicionales 
            SET modulo = ?, nombre_campo = ?, tipo_campo = ?, obligatorio = ?, estado_mostrar = ? 
            WHERE id = ?";

    $stmt = $conn->prepare($sql);
    // ✅ CORREGIDO: bind_param ahora incluye el tipo para estado_mostrar
    // "sssiii" = string, string, string, int, int(estado_mostrar), int(id)
    $stmt->bind_param("sssiii", $modulo, $nombre_campo, $tipo_campo, $obligatorio, $estado_mostrar, $id);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Campo actualizado correctamente."]);
    } else {
        echo json_encode(["success" => false, "message" => "Error al actualizar: " . $stmt->error]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Datos incompletos."]);
}
?>