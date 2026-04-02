<?php
require_once '../../login/auth_middleware.php';

$currentUser = requireAuth();
require '../../conexion.php';

$data = json_decode(file_get_contents("php://input"));

if (isset($data->id)) {
    $id = $data->id;

    $sql = "DELETE FROM campos_adicionales WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Campo eliminado correctamente."]);
    } else {
        echo json_encode(["success" => false, "message" => "Error al eliminar: " . $stmt->error]);
    }
} else {
    echo json_encode(["success" => false, "message" => "ID no recibido."]);
}
?>