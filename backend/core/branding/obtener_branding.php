<?php
require_once '../../login/auth_middleware.php';

// Asegurar headers CORS desde el inicio
if (function_exists('setCORSHeaders')) {
    setCORSHeaders();
}

try {
    $currentUser = optionalAuth();
    include '../../conexion.php';

    if (!isset($conn)) {
        throw new Exception('Error de conexión a la base de datos');
    }

    $sql = "SELECT color, logo_url, background_url, ver_tiempos FROM branding WHERE id = 1";
    $result = $conn->query($sql);

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        echo json_encode([
            'success' => true,
            'branding' => [
                'color' => $row['color'] ?? 'ff2196f3',
                'color_primario' => '#' . ($row['color'] ? substr($row['color'], -6) : '2196f3'),
                'logo_url' => $row['logo_url'] ?? null,
                'background_url' => $row['background_url'] ?? null,
                'ver_tiempos' => isset($row['ver_tiempos']) ? (int) $row['ver_tiempos'] : 0
            ]
        ]);
    } else {
        // Si no existe configuración, devolver valores por defecto 
        echo json_encode([
            'success' => true,
            'branding' => [
                'color' => 'ff2196f3', // Azul por defecto 
                'color_primario' => '#2196f3',
                'logo_url' => null,
                'background_url' => null,
                'ver_tiempos' => 0
            ]
        ]);
    }

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error al obtener configuración: ' . $e->getMessage()
    ]);
}

if (isset($conn) && $conn) {
    $conn->close();
}
?>