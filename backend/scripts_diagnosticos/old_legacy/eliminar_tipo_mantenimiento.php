<?php
header("Content-Type: application/json");

require_once '../login/auth_middleware.php';
$currentUser = requireAuth();

require 'conexion.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    $tipo = $input['tipo'] ?? null;
    
    if (!$tipo) {
        throw new Exception('Tipo de mantenimiento es requerido');
    }
    
    $tipo = trim(strtolower($tipo));
    
    // Verificar que no sea un tipo por defecto
    $tiposPorDefecto = ['preventivo', 'correctivo', 'predictivo'];
    if (in_array($tipo, $tiposPorDefecto)) {
        throw new Exception('No se pueden eliminar los tipos por defecto');
    }
    
    // Verificar si está siendo usado
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM servicios WHERE LOWER(tipo_mantenimiento) = ?");
    $stmt->bind_param("s", $tipo);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    if ($row['count'] > 0) {
        throw new Exception("No se puede eliminar. Este tipo está siendo usado por {$row['count']} servicio(s)");
    }
    
    // Si no está siendo usado, actualizar todos los registros (esto es una operación segura ya que count=0)
    $stmt = $conn->prepare("UPDATE servicios SET tipo_mantenimiento = NULL WHERE LOWER(tipo_mantenimiento) = ?");
    $stmt->bind_param("s", $tipo);
    $stmt->execute();
    
    echo json_encode([
        'success' => true,
        'message' => "Tipo '$tipo' eliminado exitosamente"
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>