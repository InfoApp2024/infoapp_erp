<?php
/**
 * verificar_config_facturacion.php
 * Endpoint para que el frontend valide si la facturación está habilitada.
 */

define('AUTH_REQUIRED', true);
require_once '../login/auth_middleware.php';
require_once '../core/FactusConfig.php';

try {
    requireAuth();
    require '../conexion.php';

    // Verificamos si la configuración mínima está presente
    $isConfigured = FactusConfig::isConfigured($conn);

    sendJsonResponse([
        'success' => true,
        'enabled' => $isConfigured,
        'message' => $isConfigured ? 'Facturación habilitada.' : 'Configure sus credenciales de Factus para habilitar la facturación.'
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
