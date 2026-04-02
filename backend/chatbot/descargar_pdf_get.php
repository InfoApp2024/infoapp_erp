<?php
// backend/chatbot/descargar_pdf_get.php
// Wrapper para descargar informes PDF vía GET (link) autenticado
// Permite que el chatbot genere enlaces directos de descarga

// 1. Simular Headers de Autenticación
// El chatbot envía el token como parámetro GET 'token'
if (isset($_GET['token'])) {
    // Legacy support: Si viene el token largo directo
    $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer ' . $_GET['token'];
} elseif (isset($_GET['t'])) {
    // Nuevo sistema: Token corto (short token)
    require_once __DIR__ . '/../conexion.php';
    
    $tokenShort = $_GET['t'];
    $stmt = $conn->prepare("SELECT jwt FROM pdf_temp_links WHERE token = ? LIMIT 1");
    $stmt->bind_param("s", $tokenShort);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer ' . $row['jwt'];
    } else {
        die("Enlace expirado o inválido.");
    }
}

// 2. Simular Petición POST
// generar_pdf.php espera POST
$_SERVER['REQUEST_METHOD'] = 'POST';

// 3. Preparar Datos
// generar_pdf.php ahora acepta $_POST gracias a nuestra modificación
// Soportar 'servicio_id' o 'id' (más corto)
$_POST['servicio_id'] = $_GET['servicio_id'] ?? ($_GET['id'] ?? 0);
$_POST['inline'] = false; // false = forzar descarga (attachment)

// 4. Invocar Script Original
// Usamos require para ejecutarlo en el mismo contexto
require_once '../informes/generar_pdf.php';
?>
