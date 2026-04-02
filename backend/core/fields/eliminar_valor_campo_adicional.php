<?php
require_once '../../login/auth_middleware.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Methods: DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

include '../../conexion.php';
try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['valor_id'])) {
        throw new Exception('ID del valor requerido');
    }
    
    $valor_id = intval($input['valor_id']);
    
    $pdo = new PDO("mysql:host=localhost;dbname=tu_base_datos", "usuario", "password");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $pdo->beginTransaction();
    
    // Obtener información del archivo si existe
    $stmt = $pdo->prepare("
        SELECT valor_archivo FROM valores_campos_adicionales WHERE id = ?
    ");
    $stmt->execute([$valor_id]);
    $valor = $stmt->fetch();
    
    if ($valor && $valor['valor_archivo']) {
        // Eliminar archivos físicos
        $archivos = ["uploads/servicios/imagenes/" . $valor['valor_archivo'],
                    "uploads/servicios/archivos/" . $valor['valor_archivo']];
        foreach ($archivos as $archivo) {
            if (file_exists($archivo)) {
                unlink($archivo);
            }
        }
        
        // Eliminar registros de archivos
        $stmt = $pdo->prepare("DELETE FROM archivos_campos_adicionales WHERE valor_campo_id = ?");
        $stmt->execute([$valor_id]);
    }
    
    // Eliminar valor
    $stmt = $pdo->prepare("DELETE FROM valores_campos_adicionales WHERE id = ?");
    $stmt->execute([$valor_id]);
    
    $pdo->commit();
    
    echo json_encode([
        'success' => true,
        'message' => 'Valor eliminado exitosamente'
    ]);
    
} catch (Exception $e) {
    if (isset($pdo)) {
        $pdo->rollBack();
    }
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}
?>
