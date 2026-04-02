<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input) {
        throw new Exception('Datos no válidos');
    }

    $color = $input['color'] ?? 'ff2196f3';
    $ver_tiempos = isset($input['ver_tiempos']) ? (int) $input['ver_tiempos'] : 0;
    $logo_base64 = $input['logo_base64'] ?? null;
    $background_base64 = $input['background_base64'] ?? null;
    $logo_url = null;
    $background_url = null;

    // Si hay un logo nuevo, guardarlo 
    if ($logo_base64) {
        $logo_url = _guardarImagen($logo_base64, 'logos');
        if (!$logo_url) {
            throw new Exception('Error al guardar el logo');
        }
    }

    // Si hay una imagen de fondo nueva, guardarla
    if ($background_base64) {
        $background_url = _guardarImagen($background_base64, 'backgrounds');
        if (!$background_url) {
            throw new Exception('Error al guardar la imagen de fondo');
        }
    }

    // Verificar si ya existe configuración 
    $checkSql = "SELECT id FROM branding WHERE id = 1";
    $checkResult = $conn->query($checkSql);

    if ($checkResult->num_rows > 0) {
        // Actualizar configuración existente 
        $updateFields = [];
        $params = [];
        $types = "";

        // Siempre actualizar color y ver_tiempos
        $updateFields[] = "color = ?";
        $params[] = $color;
        $types .= "s";

        $updateFields[] = "ver_tiempos = ?";
        $params[] = $ver_tiempos;
        $types .= "i";

        // Actualizar logo si hay uno nuevo
        if ($logo_url) {
            $updateFields[] = "logo_url = ?";
            $params[] = $logo_url;
            $types .= "s";
        }

        // Actualizar fondo si hay uno nuevo
        if ($background_url) {
            $updateFields[] = "background_url = ?";
            $params[] = $background_url;
            $types .= "s";
        }

        // Actualizar fecha
        $updateFields[] = "fecha_actualizacion = NOW()";

        $sql = "UPDATE branding SET " . implode(", ", $updateFields) . " WHERE id = 1";
        $stmt = $conn->prepare($sql);

        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
    } else {
        // Insertar nueva configuración 
        $stmt = $conn->prepare("INSERT INTO branding (id, color, logo_url, background_url, ver_tiempos, fecha_creacion) VALUES (1, ?, ?, ?, ?, NOW())");
        $stmt->bind_param("sssi", $color, $logo_url, $background_url, $ver_tiempos);
    }

    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Configuración guardada exitosamente',
            'logo_url' => $logo_url,
            'background_url' => $background_url
        ]);
    } else {
        throw new Exception('Error al guardar en base de datos');
    }

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}



function _guardarImagen($base64Data, $tipo = 'logos')
{
    try {
        // Decodificar base64 
        $imageData = base64_decode($base64Data);
        if ($imageData === false) {
            return false;
        }

        // Detectar tipo de imagen 
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mimeType = $finfo->buffer($imageData);

        // Determinar extensión 
        $extension = '';
        switch ($mimeType) {
            case 'image/jpeg':
                $extension = 'jpg';
                break;
            case 'image/png':
                $extension = 'png';
                break;
            case 'image/svg+xml':
                $extension = 'svg';
                break;
            default:
                return false;
        }

        // Definir rutas
        // Ruta en disco (Filesystem): backend/uploads
        $fsDir = __DIR__ . '/../../uploads/' . $tipo . '/';

        // Ruta Web (para BD): uploads/logos/...
        $webDir = 'uploads/' . $tipo . '/';

        // Crear directorio si no existe 
        if (!is_dir($fsDir)) {
            mkdir($fsDir, 0755, true);
        }

        // Generar nombre único 
        $fileName = $tipo == 'logos' ? 'logo_' : 'background_';
        $fileName .= time() . '.' . $extension;

        $filePath = $fsDir . $fileName;
        $webPath = $webDir . $fileName;

        // Guardar archivo 
        if (file_put_contents($filePath, $imageData)) {
            return $webPath;
        }

        return false;

    } catch (Exception $e) {
        error_log("Error guardando imagen: " . $e->getMessage());
        return false;
    }
}

$conn->close();
?>