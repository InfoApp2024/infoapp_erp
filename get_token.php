<?php
define('AUTH_REQUIRED', true);
require __DIR__ . '/backend/core/FactusService.php';

try {
    $token = FactusService::getAccessToken();
    file_put_contents('temp_token.txt', $token);
    echo "TOKEN_SAVED";
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage();
}
