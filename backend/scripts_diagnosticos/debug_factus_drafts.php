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
    curl_close($ch);

    $res = json_decode($response, true);
    return $res['access_token'] ?? null;
}

try {
    $token = getAccessToken();
    if (!$token)
        die("Error obteniendo token\n");

    // Consultar específicamente status 0 (borradores)
    $url = FACTUS_API_URL . "/v1/bills?status=0&per_page=100";

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $token,
        'Accept: application/json'
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    echo "HTTP CODE: $httpCode\n";
    $data = json_decode($response, true);

    if (isset($data['data']['data'])) {
        echo "Borradores encontrados: " . count($data['data']['data']) . "\n";
        foreach ($data['data']['data'] as $bill) {
            echo "ID: " . $bill['id'] . " | Ref: " . ($bill['reference_code'] ?? 'N/A') . " | Number: " . ($bill['number'] ?? 'N/A') . " | Status: " . ($bill['status_name'] ?? 'N/A') . "\n";
        }
    } else {
        echo "No se encontraron borradores o la respuesta no tiene el formato esperado.\n";
        echo "Full Response: " . $response . "\n";
    }

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
