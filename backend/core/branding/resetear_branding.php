<?php
require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    include '../../conexion.php';
    
    // Obtener logo actual para eliminarlo
    $sql = "SELECT logo_url FROM branding WHERE id = 1";
    $result = $conn->query($sql);

    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        $logoUrl = $row['logo_url'];

        // Eliminar archivo de logo si existe
        if ($logoUrl && file_exists($logoUrl)) {
            unlink($logoUrl);
        }
    }

    // Resetear a valores por defecto
    $stmt = $conn->prepare("UPDATE branding SET color = 'ff2196f3', logo_url = NULL, fecha_actualizacion = NOW() WHERE id = 1");

    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Configuración reseteada a valores por defecto'
        ]);
    } else {
        throw new Exception('Error al resetear configuración');
    }

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>