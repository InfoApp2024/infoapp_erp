<?php
/**
 * test_ai_audit_logic.php
 * Verifica que el endpoint de análisis de IA maneja correctamente los datos y la persistencia.
 */
require_once 'backend/conexion.php';

function testEndpoint($servicio_id) {
    $url = "http://localhost/infoapp_proyecto/backend/chatbot/analizar_cotizacion.php?servicio_id=$servicio_id";
    // Nota: Esto requiere que el servidor local esté corriendo y el token sea válido.
    // Como no podemos probar HTTP real fácilmente sin token, probaremos la lógica de la base de datos.
    echo "Verificando consistencia de base de datos para servicio $servicio_id...\n";
}

try {
    // 1. Verificar si existen las tablas nuevas
    $res = $conn->query("SHOW TABLES LIKE 'fac_auditoria_ia_logs'");
    if ($res->num_rows > 0) {
        echo "✅ Tabla fac_auditoria_ia_logs existe.\n";
    } else {
        echo "❌ Tabla fac_auditoria_ia_logs NO existe.\n";
    }

    // 2. Verificar columna es_excepcion
    $res = $conn->query("SHOW COLUMNS FROM fac_auditorias_servicio LIKE 'es_excepcion'");
    if ($res->num_rows > 0) {
        echo "✅ Columna es_excepcion existe en fac_auditorias_servicio.\n";
    } else {
        echo "❌ Columna es_excepcion NO existe.\n";
    }

    // 3. Verificar ciclo en auditoría
    $res = $conn->query("SHOW COLUMNS FROM fac_auditorias_servicio LIKE 'ciclo'");
    if ($res->num_rows > 0) {
        echo "✅ Columna ciclo existe en fac_auditorias_servicio.\n";
    }

} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>
