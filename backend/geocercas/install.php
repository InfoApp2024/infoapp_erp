<?php
// backend/geocercas/install.php
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    
    // Solo administrador puede instalar
    if ($currentUser['rol'] !== 'administrador') {
        throw new Exception("Acceso denegado. Se requiere rol de administrador.");
    }

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
        echo "Tablas de Geocercas creadas correctamente.";
    } else {
        echo "Error creando tablas: " . $conn->error;
    }

} catch (Exception $e) {
    http_response_code(403);
    echo "Error: " . $e->getMessage();
}
?>
