<?php
// backend/notas/install.php
require_once '../login/auth_middleware.php';
$currentUser = requireAuth();

require '../conexion.php';

$sql = file_get_contents('init.sql');

if ($conn->multi_query($sql)) {
    do {
        // Store first result set
        if ($result = $conn->store_result()) {
            $result->free();
        }
        // Prepare next result set
    } while ($conn->more_results() && $conn->next_result());
    echo "Tabla notas creada correctamente.";
} else {
    echo "Error creando tabla: " . $conn->error;
}
