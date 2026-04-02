<?php
define('AUTH_REQUIRED', true);
require 'core/FactusConfig.php';

function getAccessToken()
{
    $url = FACTUS_API_URL . '/oauth/token';
    $payload = [
        'grant_type' => 'password',
        'client_id' => FACTUS_CLIENT_ID,
        'client_secret' => FACTUS_CLIENT_SECRET,
        'username' => FACTUS_USERNAME,
        'password' => FACTUS_PASSWORD
    ];

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($payload));
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $res = json_decode($response, true);
    return $res['access_token'] ?? null;
}

try {
    $token = getAccessToken();
    if (!$token)
        die("Error obteniendo token\n");

    // Intentar buscar facturas en estado "PENDIENTE" o similar
    $url = FACTUS_API_URL . '/v1/bills';

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $token,
        'Accept: application/json'
    ]);

    $response = curl_exec($ch);
    curl_close($ch);

    $data = json_decode($response, true);

    echo "Analizando facturas...\n";
    if (isset($data['data']['data'])) {
        foreach ($data['data']['data'] as $bill) {
            // Imprimir todos los campos de estado y referencia
            echo json_encode([
                'id' => $bill['id'],
                'number' => $bill['number'],
                'status' => $bill['status'] ?? '?',
                'reference' => $bill['reference_code'] ?? '?',
                'is_valid' => $bill['is_valid'] ?? '?'
            ]) . "\n";
        }
    }

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
